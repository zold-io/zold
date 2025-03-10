# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'time'
require 'webmock/minitest'
require 'zold/score'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/fetch'

# FETCH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestFetch < Zold::Test
  def test_fetches_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(
        status: 200,
        body: {
          score: Zold::Score::ZERO.to_h,
          size: 10_000,
          mtime: Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}.bin")
        .to_return(status: 200, body: File.read(wallet.path))
      stub_request(:get, "http://localhost:81/wallet/#{wallet.id}").to_return(status: 404)
      remotes = home.remotes
      remotes.add('localhost', 4096)
      remotes.add('localhost', 81)
      copies = home.copies(wallet)
      Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: fake_log).run(
        ['fetch', '--tolerate-edges', '--tolerate-quorum=1', '--ignore-score-weakness', wallet.id.to_s]
      )
      assert_equal(1, copies.all.count)
      assert_equal('1', copies.all[0][:name])
      assert_equal(0, copies.all[0][:score])
    end
  end

  def test_fetches_multiple_wallets
    log = TestLogger.new(fake_log)
    FakeHome.new(log: log).run do |home|
      wallet_a = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet_a.id}").to_return(
        status: 200,
        body: {
          score: Zold::Score::ZERO.to_h,
          size: 10_000,
          mtime: Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet_a.id}.bin")
        .to_return(status: 200, body: File.read(wallet_a.path))
      wallet_b = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet_b.id}").to_return(
        status: 200,
        body: {
          score: Zold::Score::ZERO.to_h,
          size: 10_000,
          mtime: Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet_b.id}.bin")
        .to_return(status: 200, body: File.read(wallet_b.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies_a = home.copies(wallet_a)
      copies_b = home.copies(wallet_b)
      Zold::Fetch.new(wallets: home.wallets, copies: copies_a.root, remotes: remotes, log: log).run(
        [
          'fetch', '--tolerate-edges', '--tolerate-quorum=1', '--ignore-score-weakness',
          '--threads 2', wallet_a.id.to_s, wallet_b.id.to_s
        ]
      )
      assert_equal(1, copies_a.all.count)
      assert_equal('1', copies_a.all[0][:name])
      assert_equal(0, copies_a.all[0][:score])
      assert_equal(1, copies_b.all.count)
      assert_equal('1', copies_b.all[0][:name])
      assert_equal(0, copies_b.all[0][:score])
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(
        status: 200,
        body: {
          score: Zold::Score::ZERO.to_h,
          size: 10_000,
          mtime: Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}.bin")
        .to_return(status: 200, body: File.read(wallet.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies = home.copies(wallet)
      assert_raises Zold::Fetch::EdgesOnly do
        Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: fake_log).run(
          ['fetch', '--ignore-score-weakness', wallet.id.to_s]
        )
      end
    end
  end

  def test_fails_when_only_one_node
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(
        status: 200,
        body: {
          score: Zold::Score::ZERO.to_h,
          size: 10_000,
          mtime: Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}.bin")
        .to_return(status: 200, body: File.read(wallet.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies = home.copies(wallet)
      assert_raises Zold::Fetch::NoQuorum do
        Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: fake_log).run(
          ['fetch', '--tolerate-edges', '--ignore-score-weakness', wallet.id.to_s]
        )
      end
    end
  end
end
