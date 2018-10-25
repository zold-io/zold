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
require_relative '../log'
require_relative '../age'
require_relative '../size'
require_relative '../id'
require_relative '../verbose_thread'
require_relative '../sync_file'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    # How many threads to use for processing
    THREADS = [Concurrent.processor_count, 4].max

    # Queue length
    MAX_QUEUE = Concurrent.processor_count * 64

    def initialize(entrance, dir, log: Log::Quiet.new)
      @entrance = entrance
      @dir = dir
      @log = log
      @mutex = Mutex.new
    end

    def to_json
      opts = queue
      json = {
        'queue': opts.count,
        'pool.length': @pool.length,
        'pool.running': @pool.running?
      }
      json['queue_age'] = opts.empty? ? 0 : Time.now - File.mtime(File.join(@dir, opts[0]))
      @entrance.to_json.merge(json)
    end

    def start
      @entrance.start do
        FileUtils.mkdir_p(@dir)
        @pool = Concurrent::FixedThreadPool.new(
          AsyncEntrance::THREADS,
          max_queue: AsyncEntrance::MAX_QUEUE,
          fallback_policy: :abort
        )
        AsyncEntrance::THREADS.times do |t|
          @pool.post do
            Thread.current.name = "async-e##{t}"
            loop do
              VerboseThread.new(@log).run(true) { take }
              break if @pool.shuttingdown?
              sleep Random.rand(100) / 100
            end
          end
        end
        begin
          yield(self)
          cycle = 0
          while !queue.empty?
            @log.info("Stopping async entrance, #{queue.count} still in the queue (cycle=#{cycle})...")
            cycle += 1
            raise "Can't wait for async entrance to stop for so long" if cycle > 10
            sleep 1
          end
        ensure
          @log.info("Stopping async entrance, pool length is #{@pool.length}, queue length is #{@pool.queue_length}")
          @pool.shutdown
          if @pool.wait_for_termination(10)
            @log.info("Async entrance terminated peacefully with #{queue.count} wallets left in the queue")
          else
            @pool.kill
            @log.info("Async entrance was killed, #{queue.count} wallets left in the queue")
          end
        end
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      raise "Queue is too long (#{queue.count} wallets), try again later" if queue.count > AsyncEntrance::MAX_QUEUE
      start = Time.now
      SyncFile.new(file(id), log: @log).open do |f|
        IO.write(f, body)
      end
      @log.debug("Added #{id}/#{Size.new(body.length)} to the queue at pos.#{queue.count} \
in #{Age.new(start, limit: 0.05)}")
      [id]
    end

    private

    def take
      start = Time.now
      opts = queue
      return if opts.empty?
      id = opts[0]
      body = SyncFile.new(file(id), log: @log).open do |f|
        b = File.exist?(f) ? IO.read(f) : ''
        FileUtils.rm_f(f)
        b
      end
      return if body.empty?
      @entrance.push(Id.new(id), body)
      @log.debug("Pushed #{id}/#{Size.new(body.length)} to #{@entrance.class.name} \
in #{Age.new(start, limit: 0.1)} (#{queue.count} still in the queue)")
    end

    def queue
      Dir.new(@dir)
        .select { |f| f =~ /^[0-9a-f]{16}$/ }
        .sort_by { |f| File.mtime(File.join(@dir, f)) }
    end

    def file(id)
      File.join(@dir, id.to_s)
    end
  end
end
