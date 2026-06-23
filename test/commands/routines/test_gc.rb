# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../../lib/zold/commands/routines/gc'
require_relative '../../../lib/zold/wallets'
require_relative '../../fake_home'
require_relative '../../test__helper'

# Gc test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestGc < Zold::Test
  def test_collects_garbage
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      assert_equal(1, wallets.count)
      Zold::Routines::Gc.new({ 'routine-immediately' => true, 'gc-age' => 0 }, wallets, log: fake_log).exec
      assert_equal(0, wallets.count)
    end
  end

  def test_doesnt_touch_non_empty_wallets
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet.sub(
        Zold::Amount.new(zld: 39.99), "NOPREFIX@#{Zold::Id.new}",
        Zold::Key.new(file: 'fixtures/id_rsa')
      )
      Zold::Routines::Gc.new({ 'routine-immediately' => true, 'gc-age' => 0 }, wallets, log: fake_log).exec
      assert_equal(1, wallets.count)
    end
  end

  def test_doesnt_touch_fresh_wallets
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      Zold::Routines::Gc.new({ 'routine-immediately' => true, 'gc-age' => 60 * 60 }, wallets, log: fake_log).exec
      assert_equal(1, wallets.count)
    end
  end
end
