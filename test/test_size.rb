# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative 'test__helper'
require_relative '../lib/zold/size'

# Size test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestSize < Zold::Test
  def test_prints_size
    assert_equal('?', Zold::Size.new(nil).to_s)
    assert_equal('10b', Zold::Size.new(10).to_s)
    assert_equal('2Kb', Zold::Size.new(2 * 1024).to_s)
    assert_equal('9Mb', Zold::Size.new(9 * 1024 * 1024).to_s)
    assert_equal('7Gb', Zold::Size.new(7 * 1024 * 1024 * 1024).to_s)
  end
end
