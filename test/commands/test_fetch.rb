# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'time'
require 'tmpdir'
require 'webmock/minitest'
require 'zold/score'
require_relative '../../lib/zold/commands/fetch'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../fake_home'
require_relative '../test__helper'

# FETCH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestFetch < Zold::Test
  def test_fetches_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(
        status: 200,
        body: { score: Zold::Score::ZERO.to_h, size: 10_000, mtime: Time.now.utc.iso8601 }.to_json
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
      first = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{first.id}").to_return(
        status: 200,
        body: { score: Zold::Score::ZERO.to_h, size: 10_000, mtime: Time.now.utc.iso8601 }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{first.id}.bin")
        .to_return(status: 200, body: File.read(first.path))
      second = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{second.id}").to_return(
        status: 200,
        body: { score: Zold::Score::ZERO.to_h, size: 10_000, mtime: Time.now.utc.iso8601 }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{second.id}.bin")
        .to_return(status: 200, body: File.read(second.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies = home.copies(first)
      other = home.copies(second)
      Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: log).run(
        [
          'fetch', '--tolerate-edges', '--tolerate-quorum=1', '--ignore-score-weakness',
          '--threads 2', first.id.to_s, second.id.to_s
        ]
      )
      assert_equal(1, copies.all.count)
      assert_equal('1', copies.all[0][:name])
      assert_equal(0, copies.all[0][:score])
      assert_equal(1, other.all.count)
      assert_equal('1', other.all[0][:name])
      assert_equal(0, other.all[0][:score])
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}").to_return(
        status: 200,
        body: { score: Zold::Score::ZERO.to_h, size: 10_000, mtime: Time.now.utc.iso8601 }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}.bin")
        .to_return(status: 200, body: File.read(wallet.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies = home.copies(wallet)
      assert_raises(Zold::Fetch::EdgesOnly) do
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
        body: { score: Zold::Score::ZERO.to_h, size: 10_000, mtime: Time.now.utc.iso8601 }.to_json
      )
      stub_request(:get, "http://localhost:4096/wallet/#{wallet.id}.bin")
        .to_return(status: 200, body: File.read(wallet.path))
      remotes = home.remotes
      remotes.add('localhost', 4096)
      copies = home.copies(wallet)
      assert_raises(Zold::Fetch::NoQuorum) do
        Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: fake_log).run(
          ['fetch', '--tolerate-edges', '--ignore-score-weakness', wallet.id.to_s]
        )
      end
    end
  end
end
