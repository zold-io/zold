# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'webmock/minitest'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/json_page'
require_relative '../../lib/zold/commands/pull'

# PUSH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestPull < Zold::Test
  def test_pull_wallet
    FakeHome.new(log: fake_log).run do |home|
      remotes = home.remotes
      remotes.add('localhost', 4096)
      json = home.create_wallet_json
      hash = Zold::JsonPage.new(json).to_hash
      id = hash['id']
      stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 200, body: json)
      stub_request(:get, "http://localhost:4096/wallet/#{id}.bin").to_return(status: 200, body: hash['body'])
      Zold::Pull.new(wallets: home.wallets, remotes: remotes, copies: home.copies.root.to_s, log: fake_log).run(
        ['--ignore-this-stupid-option', 'pull', id.to_s, '--tolerate-edges', '--tolerate-quorum=1']
      )
      home.wallets.acq(Zold::Id.new(id)) do |wallet|
        assert(wallet.exists?)
      end
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: fake_log).run do |home|
      remotes = home.remotes
      remotes.add('localhost', 4096)
      json = home.create_wallet_json
      hash = Zold::JsonPage.new(json).to_hash
      id = hash['id']
      stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 200, body: json)
      stub_request(:get, "http://localhost:4096/wallet/#{id}.bin").to_return(status: 200, body: hash['body'])
      assert_raises Zold::Fetch::EdgesOnly do
        Zold::Pull.new(wallets: home.wallets, remotes: remotes, copies: home.copies.root.to_s, log: fake_log).run(
          ['--ignore-this-stupid-option', 'pull', id.to_s]
        )
      end
    end
  end
end
