# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative 'test__helper'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/amount'

# Wallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestWallets < Zold::Test
  def test_adds_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      id = Zold::Id.new
      wallets.acq(id) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
      end
    end
  end

  def test_lists_wallets_and_ignores_garbage
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      FileUtils.touch(File.join(home.dir, '0xaaaaaaaaaaaaaaaaaaahello'))
      FileUtils.mkdir_p(File.join(home.dir, 'a/b/c'))
      FileUtils.touch(File.join(home.dir, 'a/b/c/0000111122223333.z'))
      id = Zold::Id.new
      wallets.acq(id) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
      end
    end
  end

  def test_subtracts_dir_path_from_full_path
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        wallets = Zold::Wallets.new(Dir.pwd)
        assert_equal('.', wallets.to_s)
      end
    end
  end

  def test_count_wallets
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        5.times { |i| FileUtils.touch("wallet_#{i}#{Zold::Wallet::EXT}") }
        wallets = Zold::Wallets.new(Dir.pwd)
        assert_equal(5, wallets.count)
      end
    end
    FakeHome.new(log: fake_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      assert_equal(1, wallets.count)
    end
  end
end
