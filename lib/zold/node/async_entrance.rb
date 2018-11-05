# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
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

require 'concurrent'
require 'futex'
require 'securerandom'
require_relative '../age'
require_relative '../size'
require_relative '../id'
require_relative '../endless'
require_relative '../dir_items'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    def initialize(entrance, dir, log: Log::Quiet.new, threads: [Concurrent.processor_count, 4].max)
      @entrance = entrance
      @dir = dir
      @log = log
      @total = threads
      @mutex = Mutex.new
    end

    def to_json
      @entrance.to_json.merge(
        'queue': queue.count,
        'threads': @threads.count
      )
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      @entrance.start do
        FileUtils.mkdir_p(@dir)
        @threads = (0..@total - 1).map do |i|
          Thread.start do
            Endless.new("async-e##{i}", log: @log).run do
              take
              sleep(1)
            end
          end
        end
        begin
          yield(self)
        ensure
          @threads.each(&:kill)
        end
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      raise "Queue is too long (#{queue.count} wallets), try again later" if queue.count > 256
      start = Time.now
      loop do
        uuid = SecureRandom.uuid
        file = File.join(@dir, "#{id}-#{uuid}")
        next if File.exist?(file)
        IO.write(file, body)
        @log.debug("Added #{id}/#{Size.new(body.length)} to the queue at pos.#{queue.count} \
in #{Age.new(start, limit: 0.05)}: #{uuid}")
        break
      end
      [id]
    end

    private

    def take
      start = Time.now
      id, body = @mutex.synchronize do
        opts = queue
        return if opts.empty?
        file = File.join(@dir, opts[0])
        id = opts[0].split('-')[0]
        Thread.current.thread_variable_set(:wallet, id)
        body = IO.read(file)
        FileUtils.rm_f(file)
        [id, body]
      end
      @entrance.push(Id.new(id), body)
      @log.debug("Pushed #{id}/#{Size.new(body.length)} to #{@entrance.class.name} \
in #{Age.new(start, limit: 0.1)} (#{queue.count} still in the queue)")
    end

    def queue
      DirItems.new(@dir).fetch.select { |f| f =~ /^[0-9a-f]{16}-/ }
    end
  end
end
