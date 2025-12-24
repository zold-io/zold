# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'webmock/minitest'
require_relative 'test__helper'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/thread_pool'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/hungry_wallets'

# HungryWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestHungryWallets < Zold::Test
  def test_pulls_wallet
    FakeHome.new(log: fake_log).run do |home|
      id = Zold::Id.new
      get = stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 404)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      pool = Zold::ThreadPool.new('test', log: fake_log)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: fake_log
      )
      wallets.acq(id) { |w| assert(!w.exists?) }
      pool.join(2)
      assert_requested(get, times: 1)
    end
  end

  def test_doesnt_pull_twice_if_not_found
    FakeHome.new(log: fake_log).run do |home|
      id = Zold::Id.new
      get = stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 404)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      pool = Zold::ThreadPool.new('test', log: fake_log)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: fake_log
      )
      3.times do
        wallets.acq(id) { |w| assert(!w.exists?) }
        sleep 0.2
      end
      pool.join(2)
      assert_requested(get, times: 1)
    end
  end

  def test_doesnt_pull_wallet_if_exists
    FakeHome.new(log: fake_log).run do |home|
      pool = Zold::ThreadPool.new('test', log: fake_log)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      wallet = home.create_wallet
      get = stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(status: 200)
      wallets = Zold::HungryWallets.new(
        home.wallets, remotes, File.join(home.dir, 'copies'),
        pool, log: fake_log
      )
      wallets.acq(wallet.id) { |w| assert(w.exists?) }
      pool.join(2)
      assert_requested(get, times: 0)
    end
  end
end
