# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../fake_home'
require_relative 'fake_node'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/entrance'
require_relative '../../lib/zold/node/pipeline'
require_relative '../../lib/zold/node/spread_entrance'
require_relative 'fake_entrance'

# SpreadEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestSpreadEntrance < Zold::Test
  def test_renders_json
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet(Zold::Id.new)
      Zold::SpreadEntrance.new(
        Zold::Entrance.new(
          home.wallets,
          Zold::Pipeline.new(home.remotes, home.copies(wallet).root, 'x'),
          log: fake_log
        ),
        home.wallets, home.remotes, 'x', log: fake_log
      ).start do |e|
        assert_equal(0, e.to_json[:modified])
      end
    end
  end

  def test_ignores_duplicates
    FakeHome.new(log: fake_log).run do |home|
      FakeNode.new(log: fake_log).run(['--ignore-score-weakness']) do |port|
        wallet = home.create_wallet
        remotes = home.remotes
        remotes.add('localhost', port)
        Zold::SpreadEntrance.new(FakeEntrance.new, home.wallets, remotes, 'x', log: fake_log).start do |e|
          8.times { e.push(wallet.id, File.read(wallet.path)) }
          assert(e.to_json[:modified] < 2, "It's too big: #{e.to_json[:modified]}")
        end
      end
    end
  end
end
