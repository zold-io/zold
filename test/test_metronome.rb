# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative 'test__helper'
require_relative '../lib/zold/metronome'

# Metronome test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestMetronome < Zold::Test
  def test_start_and_stop
    metronome = Zold::Metronome.new(fake_log)
    list = []
    metronome.add(FakeRoutine.new(list))
    metronome.start do
      assert_wait { !list.empty? }
    end
  end

  def test_prints_to_text
    metronome = Zold::Metronome.new(fake_log)
    metronome.add(FakeRoutine.new([]))
    metronome.start do |m|
      assert(!m.to_text.nil?)
    end
  end

  def test_prints_empty_to_text
    metronome = Zold::Metronome.new(fake_log)
    metronome.start do |m|
      assert(!m.to_text.nil?)
    end
  end

  def test_continues_even_after_error
    metronome = Zold::Metronome.new(fake_log)
    routine = BrokenRoutine.new
    metronome.add(routine)
    metronome.start do
      assert_wait { routine.count >= 2 }
      assert(routine.count > 1)
    end
  end

  class FakeRoutine
    def initialize(list)
      @list = list
    end

    def exec(i)
      @list << i
    end
  end

  class BrokenRoutine
    attr_reader :count

    def initialize
      @count = 0
    end

    def exec(i)
      @count = i
      sleep 0.1
      raise
    end
  end
end
