# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require 'tempfile'
require 'shellwords'
require 'loog'
require_relative '../remotes'
require_relative '../copies'
require_relative '../endless'
require_relative '../tax'
require_relative '../thread_pool'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'
require_relative '../commands/clean'

# The entrance that spreads what's been modified.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # The entrance
  class SpreadEntrance
    def initialize(entrance, wallets, remotes, address, log: Loog::NULL,
      ignore_score_weakeness: false, tolerate_edges: false)
      @entrance = entrance
      @wallets = wallets
      @remotes = remotes
      @address = address
      @log = log
      @ignore_score_weakeness = ignore_score_weakeness
      @tolerate_edges = tolerate_edges
      @mutex = Mutex.new
      @push = ThreadPool.new('spread-entrance')
    end

    def to_json
      @entrance.to_json.merge(
        modified: @modified.size,
        push: @push.to_json
      )
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      @entrance.start do
        @seen = Set.new
        @modified = Queue.new
        @push.add do
          Endless.new('push', log: @log).run do
            id = @modified.pop
            if @remotes.all.empty?
              @log.info("There are no remotes, won't spread #{id}")
            elsif @wallets.acq(id) { |w| Tax.new(w).in_debt? }
              @log.info("The wallet #{id} is in debt, won't spread")
            else
              Thread.current.thread_variable_set(:wallet, id.to_s)
              Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
                ['push', "--ignore-node=#{Shellwords.escape(@address)}", id.to_s, '--tolerate-quorum=1'] +
                (@ignore_score_weakeness ? ['--ignore-score-weakness'] : []) +
                (@tolerate_edges ? ['--tolerate-edges'] : [])
              )
            end
            @mutex.synchronize { @seen.delete(id) }
          end
        end
        begin
          yield(self)
        ensure
          @modified.clear
          @push.kill
        end
      end
    end

    # This method is thread-safe
    def push(id, body)
      mods = @entrance.push(id, body)
      return mods if @remotes.all.empty?
      mods.each do |m|
        next if @seen.include?(m)
        @mutex.synchronize { @seen << m }
        @modified.push(m)
        @log.debug("Spread-push scheduled for #{m}, queue size is #{@modified.size}")
      end
      mods
    end
  end
end
