# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/hexnum'

# Hexnum test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestHexnum < Zold::Test
  def test_prints_and_parses
    [0, 1, 3, 5, 7, 13, 6447, 897_464, -1, -3, -7584, -900_098].each do |n|
      assert_equal(n, Zold::Hexnum.parse(Zold::Hexnum.new(n, 6).to_s).to_i)
    end
  end
end
