# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'tempfile'
require 'diffy'
require 'fileutils'
require_relative 'pipeline'
require_relative '../log'
require_relative '../age'

# The pipeline with journals.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
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
      jlog.level = Logger::DEBUG
      jlog.formatter = Log::COMPACT
      jlog.info("push(#{id}, #{body.length} bytes): starting...")
      jlog.info("Time: #{Time.now.utc.iso8601}")
      jlog.info("Zold gem version: #{Zold::VERSION}")
      modified = @pipeline.push(id, body, JournaledPipeline::Wallets.new(wallets, jlog), Log::Tee.new(log, jlog))
      jlog.info("push(#{id}): done")
      FileUtils.mv(journal, "#{journal}-done")
      modified
    end
  end
end
