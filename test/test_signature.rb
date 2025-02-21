# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require_relative 'test__helper'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/amount'
require_relative '../lib/zold/signature'

# Signature test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestSignature < Zold::Test
  def test_signs_and_validates
    pvt = Zold::Key.new(file: 'fixtures/id_rsa')
    pub = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    txn = Zold::Txn.new(
      123, Time.now, Zold::Amount.new(zld: 14.95),
      'NOPREFIX', Zold::Id.new, 'hello, world!'
    )
    id = Zold::Id.new
    txn = txn.signed(pvt, id)
    assert_equal(684, txn.sign.length)
    assert(Zold::Signature.new.valid?(pub, id, txn))
  end
end
