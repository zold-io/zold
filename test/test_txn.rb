# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'time'
require_relative 'test__helper'
require_relative '../lib/zold/id'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/amount'

# Txn test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestTxn < Zold::Test
  def test_prints_and_parses
    time = Time.now
    txn = Zold::Txn.parse(
      Zold::Txn.new(
        123, time, Zold::Amount.new(zld: -99.95),
        'NOPREFIX', Zold::Id.new,
        'Some details to see 123. Works, or not.'
      ).to_s
    )
    assert_equal(123, txn.id)
    assert_equal('-99.95', txn.amount.to_zld)
    assert_equal('NOPREFIX', txn.prefix)
  end

  def test_converts_to_json
    time = Time.now
    txn = Zold::Txn.new(
      123, time, Zold::Amount.new(zld: -99.95),
      'NOPREFIX', Zold::Id.new('0123012301230123'),
      'Some details to see'
    )
    json = txn.to_json
    assert_equal(123, json[:id])
    assert_equal(-429_281_981_235, json[:amount])
    assert_equal('NOPREFIX', json[:prefix])
    assert_equal('0123012301230123', json[:bnf])
    assert_equal('Some details to see', json[:details])
  end

  def test_accepts_text_as_details
    [
      'How are you, dude?! I\'m @yegor256: *_hello_',
      'For a pizza to my friend: John! Good? Works.',
      'ZLD exchange to 0.00104 BTC at 3NimQKG2kuseH3cz3hdbdEHbqai9kj, rate is 0.00026, fee is 0.08'
    ].each do |details|
      txn = Zold::Txn.parse(
        Zold::Txn.new(
          123, Time.now, Zold::Amount.new(zld: -99.95),
          'NOPREFIX', Zold::Id.new,
          details
        ).to_s
      )
      assert_equal(details, txn.details)
    end
  end

  def test_prints_and_parses_time
    10.times do |i|
      time = Time.now + (i * 12_345)
      iso = time.utc.iso8601
      assert_equal(time.to_s, Zold::Txn.parse_time(iso).to_s)
    end
  end
end
