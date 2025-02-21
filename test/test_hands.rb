# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'concurrent'
require_relative 'test__helper'
require_relative '../lib/zold/hands'

# Hands test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestHands < Zold::Test
  def test_runs_in_many_threads
    idx = Concurrent::AtomicFixnum.new
    threads = 50
    Zold::Hands.exec(threads) do
      idx.increment
    end
    assert_equal(threads, idx.value)
  end

  def test_runs_with_empty_set
    Zold::Hands.exec(5, []) do
      # nothing
    end
  end

  def test_runs_with_index
    idx = Concurrent::AtomicFixnum.new
    indexes = Set.new
    Zold::Hands.exec(10, %w[a b c]) do |_, i|
      idx.increment
      indexes << i
    end
    assert_equal(3, idx.value)
    assert_equal('0 1 2', indexes.to_a.sort.join(' '))
  end

  def test_runs_with_exceptions
    assert_raises do
      Zold::Hands.exec(5) do |i|
        if i == 4
          sleep 0.1
          raise 'intended'
        end
      end
    end
  end
end
