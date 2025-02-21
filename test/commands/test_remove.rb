# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/commands/remove'

# REMOVE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestRemove < Zold::Test
  def test_removes_one_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      assert_equal(1, home.wallets.all.count)
      Zold::Remove.new(wallets: home.wallets, log: fake_log).run(['remove', wallet.id.to_s])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_wallets
    FakeHome.new(log: fake_log).run do |home|
      home.create_wallet
      home.create_wallet
      Zold::Remove.new(wallets: home.wallets, log: fake_log).run(['remove'])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_no_wallets
    FakeHome.new(log: fake_log).run do |home|
      Zold::Remove.new(wallets: home.wallets, log: fake_log).run(['remove'])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_absent_wallets
    FakeHome.new(log: fake_log).run do |home|
      Zold::Remove.new(wallets: home.wallets, log: fake_log).run(
        ['remove', '7654321076543210', '--force']
      )
      assert(home.wallets.all.empty?)
    end
  end
end
