# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/node/safe_entrance'
require_relative '../../lib/zold/node/soft_error'
require_relative 'fake_entrance'

# SafeEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestSafeEntrance < Zold::Test
  def test_rejects_wallet_with_negative_balance
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      assert_raises Zold::SoftError do
        Zold::SafeEntrance.new(FakeEntrance.new).push(wallet.id, File.read(wallet.path))
      end
    end
  end

  def test_rejects_wallet_with_wrong_network
    FakeHome.new(log: fake_log).run do |home|
      wallet = Zold::Wallet.new(File.join(home.dir, 'wallet.z'))
      wallet.init(Zold::Id.new, Zold::Key.new(file: 'fixtures/id_rsa.pub'), network: 'someothernetwork')
      assert_raises StandardError do
        Zold::SafeEntrance.new(FakeEntrance.new).push(wallet.id, File.read(wallet.path))
      end
    end
  end
end
