# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative 'test__helper'
require_relative '../lib/zold/id'

# ID test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestId < Zold::Test
  def test_generates_new_id
    50.times do
      id = Zold::Id.new
      assert_equal 16, id.to_s.length
    end
  end

  def test_generates_different_ids
    before = ''
    500.times do
      id = Zold::Id.new
      refute_equal id.to_s, before.to_s
      before = id
    end
  end

  def test_list_of_banned_ids_is_not_empty
    refute_empty(Zold::Id::BANNED)
  end

  def test_checks_for_root
    assert_predicate(Zold::Id::ROOT, :root?)
  end

  def test_generates_id_only_once
    id = Zold::Id.new
    before = id.to_s
    5.times do
      assert_equal id.to_s, before
    end
  end

  def test_parses_id
    hex = 'ff01889402fe0954'
    id = Zold::Id.new(hex)
    assert_equal(id.to_s, hex, "#{id} is not equal to #{hex}")
  end

  def test_compares_two_ids_by_text
    id = Zold::Id.new.to_s
    assert_equal(Zold::Id.new(id), Zold::Id.new(id))
  end

  def test_compares_two_ids
    assert_equal Zold::Id.new(Zold::Id::ROOT.to_s), Zold::Id.new('0000000000000000')
  end
end
