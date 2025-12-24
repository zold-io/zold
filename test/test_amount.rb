# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/zold/amount'

# Amount test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestAmount < Zold::Test
  def test_parses_zld
    amount = Zold::Amount.new(zld: 14.95)
    assert_includes(
      amount.to_s, '14.95ZLD',
      "#{amount} is not equal to '14.95ZLD'"
    )
  end

  def test_prints_zld_with_many_digits
    amount = Zold::Amount.new(zld: 0.12345678)
    assert_equal('0.123', amount.to_zld(3))
    assert_equal('0.1235', amount.to_zld(4))
    assert_equal('0.12346', amount.to_zld(5))
    assert_equal('0.123457', amount.to_zld(6))
  end

  def test_compares_with_zero
    amount = Zold::Amount.new(zld: 0.00001)
    refute_predicate(amount, :zero?)
    assert_predicate(amount, :positive?)
    refute_predicate(amount, :negative?)
    refute_equal(amount, Zold::Amount::ZERO)
  end

  def test_parses_zents
    amount = Zold::Amount.new(zents: 900_000_000)
    assert_includes(
      amount.to_s, '0.21ZLD',
      "#{amount} is not equal to '0.21ZLD'"
    )
  end

  def test_compares_amounts
    amount = Zold::Amount.new(zents: 700_000_000)
    assert_operator(
      amount, :>, Zold::Amount::ZERO, "#{amount} is not greater than zero"
    )
  end

  def test_multiplies
    amount = Zold::Amount.new(zld: 1.2)
    assert_equal(Zold::Amount.new(zld: 2.4), amount * 2)
  end

  def test_divides
    amount = Zold::Amount.new(zld: 8.2)
    assert_equal(Zold::Amount.new(zld: 4.1), amount / 2)
  end
end
