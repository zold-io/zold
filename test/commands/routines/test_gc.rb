# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../test__helper'
require_relative '../../fake_home'
require_relative '../../../lib/zold/wallets'
require_relative '../../../lib/zold/commands/routines/gc'

# Gc test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestGc < Zold::Test
  def test_collects_garbage
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      opts = { 'routine-immediately' => true, 'gc-age' => 0 }
      assert_equal(1, wallets.count)
      routine = Zold::Routines::Gc.new(opts, wallets, log: fake_log)
      routine.exec
      assert_equal(0, wallets.count)
    end
  end

  def test_doesnt_touch_non_empty_wallets
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      opts = { 'routine-immediately' => true, 'gc-age' => 0 }
      routine = Zold::Routines::Gc.new(opts, wallets, log: fake_log)
      routine.exec
      assert_equal(1, wallets.count)
    end
  end

  def test_doesnt_touch_fresh_wallets
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      opts = { 'routine-immediately' => true, 'gc-age' => 60 * 60 }
      routine = Zold::Routines::Gc.new(opts, wallets, log: fake_log)
      routine.exec
      assert_equal(1, wallets.count)
    end
  end
end
