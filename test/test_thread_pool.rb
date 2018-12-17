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

require 'minitest/autorun'
require 'concurrent'
require_relative 'test__helper'
require_relative '../lib/zold/thread_pool'

# ThreadPool test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestThreadPool < Zold::Test
  def test_closes_all_threads_right
    pool = Zold::ThreadPool.new('test', log: test_log)
    idx = Concurrent::AtomicFixnum.new
    threads = 50
    threads.times do
      pool.add do
        idx.increment
      end
    end
    pool.kill
    assert_equal(threads, idx.value)
  end

  def test_runs_in_many_threads
    idx = Concurrent::AtomicFixnum.new
    threads = 50
    Zold::ThreadPool.new('test', log: test_log).run(threads) do
      idx.increment
    end
    assert_equal(threads, idx.value)
  end

  def test_runs_with_empty_set
    Zold::ThreadPool.new('test', log: test_log).run(5, []) do
      # nothing
    end
  end

  def test_runs_with_index
    idx = Concurrent::AtomicFixnum.new
    indexes = Set.new
    Zold::ThreadPool.new('test', log: test_log).run(10, %w[a b c]) do |_, i|
      idx.increment
      indexes << i
    end
    assert_equal(3, idx.value)
    assert_equal('0 1 2', indexes.to_a.sort.join(' '))
  end

  def test_runs_with_exceptions
    assert_raises do
      Zold::ThreadPool.new('test', log: test_log).run(1) do
        raise 'intended'
      end
    end
  end

  def test_adds_and_stops
    pool = Zold::ThreadPool.new('test', log: test_log)
    pool.add do
      sleep 60 * 60
    end
    pool.kill
  end

  def test_stops_stuck_threads
    pool = Zold::ThreadPool.new('test', log: test_log)
    pool.add do
      loop do
        # forever
      end
    end
    pool.kill
  end

  def test_stops_empty_pool
    pool = Zold::ThreadPool.new('test', log: test_log)
    pool.kill
  end

  def test_prints_to_json
    pool = Zold::ThreadPool.new('test', log: test_log)
    assert(pool.to_json.is_a?(Array))
  end

  def test_prints_to_text
    pool = Zold::ThreadPool.new('test', log: test_log)
    assert(!pool.to_s.nil?)
  end
end
