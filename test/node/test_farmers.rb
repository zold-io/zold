# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'time'
require 'zold/score'
require_relative '../test__helper'
require_relative '../../lib/zold/node/farmers'
require_relative '../../lib/zold/verbose_thread'

class FarmersTest < Zold::Test
  # Types to test
  TYPES = [
    Zold::Farmers::Plain,
    Zold::Farmers::Spawn,
    Zold::Farmers::Fork
  ].freeze

  def test_calculates_next_score
    before = Zold::Score.new(host: 'some-host', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 3)
    TYPES.each do |farmer_class|
      farmer = farmer_class.new(log: fake_log)
      after = farmer.up(before)
      assert_equal(1, after.value)
      assert(!after.expired?)
      assert_equal('some-host', after.host)
      assert_equal(9999, after.port)
    end
  end

  def test_calculates_large_score
    TYPES.each do |type|
      log = TestLogger.new(fake_log)
      thread = Thread.start do
        farmer = type.new(log: log)
        farmer.up(Zold::Score.new(host: 'a', port: 1, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 20))
      end
      sleep(0.1)
      thread.kill
      thread.join
    end
  end

  def test_kills_farmer
    TYPES.each do |type|
      farmer = type.new(log: fake_log)
      thread = Thread.start do
        Zold::VerboseThread.new(fake_log).run do
          farmer.up(Zold::Score.new(host: 'some-host', invoice: 'NOPREFIX4@ffffffffffffffff', strength: 32))
        end
      end
      sleep(1)
      thread.kill
      thread.join
    end
  end
end
