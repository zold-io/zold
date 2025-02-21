# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative 'test__helper'
require_relative '../lib/zold/json_page'

# JsonPage test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestJsonPage < Zold::Test
  def test_parses_json_page
    assert_equal(1, Zold::JsonPage.new('{"x": 1}').to_hash['x'])
  end

  def test_parses_broken_json_page
    assert_raises Zold::JsonPage::CantParse do
      Zold::JsonPage.new('not json').to_hash
    end
  end

  def test_parses_empty_page
    assert_raises Zold::JsonPage::CantParse do
      Zold::JsonPage.new('').to_hash
    end
  end
end
