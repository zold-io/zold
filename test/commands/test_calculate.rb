# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require 'loog'
require_relative '../../lib/zold/commands/calculate'

# SCORE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestCalculate < Zold::Test
  def test_calculates_score
    score = Zold::Calculate.new(log: fake_log).run(
      ['score', '--strength=2', '--max=8', '--invoice=NOSUFFIX@ffffffffffffffff']
    )
    assert_predicate(score, :valid?)
    assert_equal(8, score.value)
  end
end
