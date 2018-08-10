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
        raise "'#{actual}' is not equal to '#{expected}' even after #{sec.round}s of waiting" if sec > max
      end
    end

    def test_log
      require_relative '../lib/zold/log'
      @test_log = Zold::Log::Verbose.new
      @test_log = Zold::Log::Quiet.new if ENV['TEST_QUIET_LOG']
      @test_log
    end
  end
end
