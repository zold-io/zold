# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/node'
require_relative '../../lib/zold/commands/fetch'
require_relative '../../lib/zold/commands/push'
require_relative '../node/fake_node'

# NODE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestNode < Zold::Test
  def test_push_and_fetch
    FakeHome.new(log: fake_log).run do |home|
      FakeNode.new(log: fake_log).run do |port|
        wallets = home.wallets
        wallet = home.create_wallet
        remotes = home.remotes
        remotes.add('localhost', port)
        Zold::Push.new(wallets: wallets, remotes: remotes, log: fake_log).run(
          ['push', '--ignore-score-weakness', '--tolerate-edges', '--tolerate-quorum=1']
        )
        copies = home.copies(wallet)
        begin
          retries ||= 0
          Zold::Fetch.new(
            wallets: wallets, copies: copies.root,
            remotes: remotes, log: fake_log
          ).run(['fetch', '--ignore-score-weakness', '--tolerate-edges', '--tolerate-quorum=1'])
        rescue StandardError => _e
          sleep 1
          retry if (retries += 1) < 3
        end
        assert_equal(1, copies.all.count)
        assert_equal('1', copies.all[0][:name])
      end
    end
  end
end
