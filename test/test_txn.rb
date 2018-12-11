# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'tmpdir'
require 'time'
require_relative 'test__helper'
require_relative '../lib/zold/id'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/amount'

# Txn test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
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
    details = 'How are you, dude?! I\'m @yegor256: *_hello_'
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
