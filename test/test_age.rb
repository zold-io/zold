# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/zold/age'

# Age test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestAge < Zold::Test
  def test_prints_age
    assert_equal('10m', Zold::Age.new(Time.now - (10 * 60)).to_s)
    assert_equal('5.5s', Zold::Age.new(Time.now - 5.5).to_s)
    assert_equal('?', Zold::Age.new(nil).to_s)
    refute_nil(Zold::Age.new(Time.now.utc.iso8601).to_s)
  end

  def test_prints_all_ages
    [
      0,
      1,
      63,
      63 * 60,
      27 * 60 * 60,
      13 * 24 * 60 * 60,
      30 * 24 * 60 * 60,
      5 * 30 * 24 * 60 * 60,
      15 * 30 * 24 * 60 * 60,
      8 * 12 * 30 * 24 * 60 * 60
    ].each do |s|
      refute_nil(Zold::Age.new(Time.now - s).to_s)
    end
  end
end
