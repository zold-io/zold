# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/commands/propagate'
require_relative '../../lib/zold/commands/pay'

# PROPAGATE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestPropagate < Zold::Test
  def test_propagates_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      friend = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: fake_log).run(
        ['pay', wallet.id.to_s, friend.id.to_s, amount.to_zld, '--force', '--private-key=fixtures/id_rsa']
      )
      Zold::Propagate.new(wallets: home.wallets, log: fake_log).run(
        ['merge', wallet.id.to_s]
      )
      assert(amount, friend.balance)
      assert(1, friend.txns.count)
      assert('', friend.txns[0].sign)
    end
  end
end
