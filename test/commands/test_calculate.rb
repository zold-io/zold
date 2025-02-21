# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/commands/calculate'

# SCORE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestCalculate < Zold::Test
  def test_calculates_score
    score = Zold::Calculate.new(log: fake_log).run(
      ['score', '--strength=2', '--max=8', '--invoice=NOSUFFIX@ffffffffffffffff']
    )
    assert(score.valid?)
    assert_equal(8, score.value)
  end
end
