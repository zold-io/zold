# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require_relative 'test__helper'
require_relative '../lib/zold/thread_pool'

# ThreadPool test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestThreadPool < Zold::Test
  def test_closes_all_threads_right
    pool = Zold::ThreadPool.new('test', log: fake_log)
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

  def test_adds_and_stops
    pool = Zold::ThreadPool.new('test', log: fake_log)
    pool.add do
      sleep 60 * 60
    end
    pool.kill
  end

  def test_stops_stuck_threads
    pool = Zold::ThreadPool.new('test', log: fake_log)
    pool.add do
      loop do
        # forever
      end
    end
    pool.kill
  end

  def test_stops_empty_pool
    pool = Zold::ThreadPool.new('test', log: fake_log)
    pool.kill
  end

  def test_prints_to_json
    pool = Zold::ThreadPool.new('test', log: fake_log)
    pool.add do
      Thread.current.thread_variable_set(:foo, 1)
      loop do
        # forever
      end
    end
    assert_kind_of(Array, pool.to_json)
    assert_equal('test', pool.to_json[0][:name])
    assert_equal('run', pool.to_json[0][:status])
    assert(pool.to_json[0][:alive])
    assert_equal(1, pool.to_json[0][:vars]['foo'])
    pool.kill
  end

  def test_prints_to_text
    pool = Zold::ThreadPool.new('test', log: fake_log)
    refute_nil(pool.to_s)
  end
end
