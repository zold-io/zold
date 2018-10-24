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

gem 'openssl'
require 'openssl'
require 'minitest/autorun'
require 'concurrent'
require 'moneta'

STDOUT.sync = true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start
if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

module Minitest
  class Test
    def assert_wait(max: 30)
      assert_equal_wait(true, max: max) { yield }
    end

    def assert_equal_wait(expected, max: 30)
      start = Time.now
      loop do
        actual = yield
        if expected == actual
          assert_equal(expected, actual)
          break
        end
        sleep 1
        sec = Time.now - start
        require_relative '../lib/zold/age'
        raise "'#{actual}' is not equal to '#{expected}' even after #{Zold::Age.new(start)} of waiting" if sec > max
      end
    end

    def assert_in_threads(threads: Concurrent.processor_count * 8, loops: 0)
      done = Concurrent::AtomicFixnum.new
      cycles = Concurrent::AtomicFixnum.new
      pool = Concurrent::FixedThreadPool.new(threads)
      latch = Concurrent::CountDownLatch.new(1)
      threads.times do |t|
        pool.post do
          Thread.current.name = "assert-thread-#{t}"
          latch.wait(10)
          loop do
            Zold::VerboseThread.new(test_log).run(true) do
              yield t
            end
            cycles.increment
            break if cycles.value > loops
          end
          done.increment
        end
      end
      latch.count_down
      pool.shutdown
      raise "Can't stop the pool" unless pool.wait_for_termination(10)
      assert_equal(threads, done.value)
    end

    def test_log
      require_relative '../lib/zold/log'
      @test_log ||= Zold::Log::Sync.new(ENV['TEST_QUIET_LOG'] ? Zold::Log::Quiet.new : Zold::Log::Verbose.new)
    end

    class TestLogger
      attr_accessor :msg
      def initialize
        @msg = []
      end

      def info(msg)
        @msg << msg
      end

      def debug(msg); end
    end
  end
end
