# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'concurrent'
require 'threads'
require_relative 'test__helper'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/sync_wallets'
require_relative '../lib/zold/amount'

# SyncWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestSyncWallets < Zold::Test
  def test_adds_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      id = Zold::Id.new
      home.create_wallet(id)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      amount = Zold::Amount.new(zld: 5.0)
      Threads.new(5).assert(100) do
        wallets.acq(id, exclusive: true) do |wallet|
          wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
          wallet.refurbish
        end
      end
      # assert_equal_wait(amount * -100, max: 4) do
      #   wallets.acq(id, &:balance)
      # end
    end
  end
end
