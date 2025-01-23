# frozen_string_literal: true

# Copyright (c) 2018-2025 Zerocracy
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
require 'total'
require_relative 'thread_pool'
require_relative 'log'
require_relative 'endless'

# Multiple threads that can do something useful together.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Hands
  class Hands
    # Pool of threads
    POOL = ThreadPool.new('default')
    private_constant :POOL

    # Queue of jobs
    QUEUE = Queue.new
    private_constant :QUEUE

    def self.threshold
      advised = Total::Mem.new.bytes / (128 * 1024 * 1024)
      advised.clamp(4, Concurrent.processor_count * 4)
    rescue Total::CantDetect
      4
    end

    # Start
    def self.start(max = Hands.threshold, log: Log::NULL)
      while POOL.count < max
        POOL.add do
          Endless.new('hands').run do
            QUEUE.pop.call
          end
        end
      end
      log.debug("There are #{POOL.count} threads in the 'hands' pool")
    end

    # Stop
    def self.stop
      POOL.kill
    end

    # Run this code in many threads
    def self.exec(threads, set = (0..threads - 1).to_a, &block)
      raise 'The thread pool is empty' if POOL.empty?
      raise "Number of threads #{threads} has to be positive" unless threads.positive?
      list = set.dup
      total = [threads, set.count].min
      if total == 1
        list.each_with_index(&block)
      elsif total.positive?
        idx = Concurrent::AtomicFixnum.new
        mutex = Mutex.new
        latch = Concurrent::CountDownLatch.new(total)
        errors = Set.new
        total.times do |i|
          QUEUE.push(
            lambda do
              Thread.current.name = "#{@title}-#{i}"
              loop do
                r = mutex.synchronize { list.pop }
                break if r.nil?
                yield(r, idx.increment - 1)
              end
            rescue StandardError => e
              errors << e
              raise e
            ensure
              latch.count_down
            end
          )
        end
        latch.wait
        raise errors.to_a[0] unless errors.empty?
      end
    end
  end
end
