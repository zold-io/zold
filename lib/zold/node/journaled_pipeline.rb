# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'diffy'
require 'fileutils'
require_relative 'pipeline'
require 'loog'
require 'loog/tee'
require 'logger'
require_relative '../age'

# The pipeline with journals.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # The entrance that keeps a journal for each wallet
  class JournaledPipeline
    # Decorated wallets
    class Wallets < SimpleDelegator
      def initialize(wallets, log)
        @wallets = wallets
        @log = log
        super(wallets)
      end

      def acq(id, exclusive: false)
        @wallets.acq(id, exclusive: exclusive) do |wallet|
          return yield wallet unless exclusive
          before = wallet.exists? ? File.read(wallet.path) : ''
          res = yield wallet
          after = wallet.exists? ? File.read(wallet.path) : ''
          unless before == after
            diff = Diffy::Diff.new(before, after, context: 0).to_s
            @log.info("The wallet #{id} was modified:\n  #{diff.gsub("\n", "\n  ")}")
          end
          res
        end
      end
    end

    def initialize(pipeline, dir)
      @pipeline = pipeline
      @dir = dir
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      FileUtils.mkdir_p(@dir)
      yield(self)
    end

    def to_json
      @pipeline.to_json.merge(
        dir: @dir
      )
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body, wallets, log, lifetime: 6)
      DirItems.new(@dir).fetch.each do |f|
        f = File.join(@dir, f)
        File.delete(f) if File.mtime(f) < Time.now - (lifetime * 60 * 60)
      end
      journal = File.join(@dir, "#{Time.now.utc.iso8601.gsub(/[^0-9]/, '-')}-#{id}")
      jlog = Logger.new(journal)
      jlog.info("push(#{id}, #{body.length} bytes): starting...")
      jlog.info("Time: #{Time.now.utc.iso8601}")
      jlog.info("Zold gem version: #{Zold::VERSION}")
      modified = @pipeline.push(id, body, JournaledPipeline::Wallets.new(wallets, jlog), Loog::Tee.new(log, jlog))
      jlog.info("push(#{id}): done")
      FileUtils.mv(journal, "#{journal}-done")
      modified
    end
  end
end
