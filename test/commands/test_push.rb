# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/push'

# PUSH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestPush < Zold::Test
  def test_pushes_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      Zold::Push.new(wallets: home.wallets, remotes: remotes, log: fake_log).run(
        ['--ignore-this-stupid-option', 'push', wallet.id.to_s, '--tolerate-edges', '--tolerate-quorum=1']
      )
    end
  end

  def test_pushes_multiple_wallets
    log = TestLogger.new(fake_log)
    FakeHome.new(log: log).run do |home|
      wallet_a = home.create_wallet
      wallet_b = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet_a.id}").to_return(status: 304)
      stub_request(:put, "http://localhost:80/wallet/#{wallet_b.id}").to_return(status: 304)
      Zold::Push.new(wallets: home.wallets, remotes: remotes, log: log).run(
        ['--tolerate-edges', '--tolerate-quorum=1', '--threads=2', 'push', wallet_a.id.to_s, wallet_b.id.to_s]
      )
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      assert_raises Zold::Push::EdgesOnly do
        Zold::Push.new(wallets: home.wallets, remotes: remotes, log: fake_log).run(
          ['push', wallet.id.to_s]
        )
      end
    end
  end

  def test_fails_when_only_one_node
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      assert_raises Zold::Push::NoQuorum do
        Zold::Push.new(wallets: home.wallets, remotes: remotes, log: fake_log).run(
          ['push', wallet.id.to_s, '--tolerate-edges']
        )
      end
    end
  end
end
