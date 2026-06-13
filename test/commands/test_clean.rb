# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'threads'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/commands/clean'

# CLEAN test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestClean < Zold::Test
  def test_cleans_copies
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      copies.add('a1', 'host-1', 80, 1, time: Time.now - (26 * 60 * 60))
      copies.add('a2', 'host-2', 80, 2, time: Time.now - (26 * 60 * 60))
      Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: fake_log).run(['clean', wallet.id.to_s])
      assert_empty(copies.all)
    end
  end

  def test_clean_no_copies
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: fake_log).run(['clean'])
      assert_empty(copies.all)
    end
  end

  def test_cleans_empty_wallets
    FakeHome.new(log: fake_log).run do |home|
      Zold::Clean.new(wallets: home.wallets, copies: File.join(home.dir, 'c'), log: fake_log).run(['clean'])
    end
  end

  def test_cleans_copies_in_threads
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      copies.add(File.read(wallet.path), 'host-2', 80, 2, time: Time.now)
      Threads.new(20).assert do
        Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: fake_log).run(['clean'])
      end
      assert_equal(1, copies.all.count)
    end
  end
end
