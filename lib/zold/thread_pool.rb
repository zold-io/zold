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
require_relative 'age'
require_relative 'verbose_thread'

# Thread pool.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Thread pool
  class ThreadPool
    def initialize(title, log: Log::NULL)
      @title = title
      @log = log
      @threads = []
      @start = Time.now
    end

    # Run this code in many threads
    def run(threads, set = (0..threads - 1).to_a)
      raise "Number of threads #{threads} has to be positive" unless threads.positive?
      idx = Concurrent::AtomicFixnum.new
      mutex = Mutex.new
      list = set.dup
      total = [threads, set.count].min
      latch = Concurrent::CountDownLatch.new(total)
      total.times do
        add do
          loop do
            r = mutex.synchronize { list.pop }
            break if r.nil?
            yield(r, idx.increment - 1)
          end
        ensure
          latch.count_down
        end
      end
      latch.wait
      kill
    end

    # Add a new thread
    def add
      raise 'Block must be given to start()' unless block_given?
      latch = Concurrent::CountDownLatch.new(1)
      thread = Thread.start do
        VerboseThread.new(@log).run do
          latch.count_down
          yield
        end
      end
      latch.wait
      Thread.current.thread_variable_set(
        :kids,
        (Thread.current.thread_variable_get(:kids) || []) + [thread]
      )
      @threads << thread
    end

    def join(sec)
      @threads.each { |t| t.join(sec) }
    end

    # Kill them all immediately and close the pool
    def kill
      if @threads.empty?
        @log.debug("Thread pool \"#{@title}\" terminated with no threads")
        return
      end
      @log.info("Stopping \"#{@title}\" thread pool with #{@threads.count} threads: \
#{@threads.map { |t| "#{t.name}/#{t.status}" }.join(', ')}...")
      start = Time.new
      @threads.each do |t|
        (t.thread_variable_get(:kids) || []).each(&:kill)
        t.kill
        raise "Failed to join the thread \"#{t.name}\" in \"#{@title}\" pool" unless t.join(0.1)
        Thread.current.thread_variable_set(
          :kids,
          (Thread.current.thread_variable_get(:kids) || []) - [t]
        )
      end
      @log.info("Thread pool \"#{@title}\" terminated all threads in #{Age.new(start)}, \
it was alive for #{Age.new(@start)}: #{@threads.map { |t| "#{t.name}/#{t.status}" }.join(', ')}")
      @threads.clear
    end

    # How many threads are in there
    def count
      @threads.count
    end

    # A thread with this name exists?
    def exists?(name)
      !@threads.find { |t| t.name == name }.nil?
    end

    # As a hash map
    def to_json
      @threads.map do |t|
        {
          name: t.name,
          status: t.status,
          alive: t.alive?,
          vars: t.thread_variables.map { |v| { v.to_s => t.thread_variable_get(v) } }
        }
      end
    end

    # As a text
    def to_s
      @threads.map do |t|
        [
          "#{t.name}: status=#{t.status}; alive=#{t.alive?}",
          'Vars: ' + t.thread_variables.map { |v| "#{v}=\"#{t.thread_variable_get(v)}\"" }.join('; '),
          t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
        ].join("\n")
      end
    end
  end
end
