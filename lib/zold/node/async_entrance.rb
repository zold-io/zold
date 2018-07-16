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
require_relative '../id'
require_relative '../verbose_thread'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    THREADS = Concurrent.processor_count * 4

    def initialize(entrance, dir, log: Log::Quiet.new)
      raise 'Entrance can\'t be nil' if entrance.nil?
      @entrance = entrance
      raise 'Directory can\'t be nil' if dir.nil?
      raise 'Directory must be of type String' unless dir.is_a?(String)
      @dir = dir
      raise 'Log can\'t be nil' if log.nil?
      @log = log
      @mutex = Mutex.new
    end

    def to_json
      json = {
        'queue': queue.count,
        'pool.length': @pool.length,
        'pool.running': @pool.running?
      }
      opts = queue
      json['queue_age'] = opts.empty? ? 0 : Time.now - File.mtime(File.join(@dir, opts[0]))
      @entrance.to_json.merge(json)
    end

    def start
      @entrance.start do
        FileUtils.mkdir_p(@dir)
        @pool = Concurrent::FixedThreadPool.new(
          AsyncEntrance::THREADS, max_queue: AsyncEntrance::THREADS, fallback_policy: :abort
        )
        AsyncEntrance::THREADS.times do
          @pool.post do
            loop do
              VerboseThread.new(@log).run(true) do
                take
                break if @pool.shuttingdown?
                sleep Random.rand(100) / 100
              end
            end
          end
        end
        begin
          yield(self)
        ensure
          @log.info("Stopping async entrance, pool length is #{@pool.length}, queue length is #{@pool.queue_length}")
          @pool.shutdown
          if @pool.wait_for_termination(10)
            @log.info('Async entrance terminated peacefully')
          else
            @pool.kill
            @log.info('Async entrance was killed')
          end
        end
      end
    end

    def push(id, body)
      @mutex.synchronize do
        AtomicFile.new(File.join(@dir, id.to_s)).write(body)
      end
    end

    private

    def take
      id = ''
      body = ''
      @mutex.synchronize do
        opts = queue
        unless opts.empty?
          file = File.join(@dir, opts[0])
          id = opts[0]
          body = File.read(file)
          File.delete(file)
        end
      end
      return if id.empty? || body.empty?
      start = Time.now
      @entrance.push(Id.new(id), body)
      @log.debug("Pushed #{id}/#{body.length}b to #{@entrance.class.name} in #{(Time.now - start).round}s")
    end

    def queue
      Dir.new(@dir)
        .select { |f| f =~ /^[0-9a-f]{16}$/ }
        .sort_by { |f| File.mtime(File.join(@dir, f)) }
    end
  end
end
