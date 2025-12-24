# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative 'test__helper'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/tree_wallets'

# TreeWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestTreeWallets < Zold::Test
  def test_adds_wallet
    Dir.mktmpdir do |dir|
      wallets = Zold::TreeWallets.new(dir)
      id = Zold::Id.new('abcd0123abcd0123')
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert(wallet.path.end_with?('/a/b/c/d/abcd0123abcd0123.z'))
      end
      assert_equal(1, wallets.all.count)
      assert_equal(id, wallets.all[0])
    end
  end

  def test_adds_many_wallets
    Dir.mktmpdir do |dir|
      wallets = Zold::TreeWallets.new(dir)
      10.times do
        id = Zold::Id.new
        wallets.acq(id, exclusive: true) do |wallet|
          wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        end
      end
      assert_equal(10, wallets.all.count)
    end
  end

  def test_count_tree_wallets
    files = [
      "0000111122223333#{Zold::Wallet::EXT}",
      "a/b/d/e/0000111122223333#{Zold::Wallet::EXT}",
      "a/b/0000111122223333#{Zold::Wallet::EXT}"
    ]
    garbage = [
      '0000111122223333',
      '0000111122223333.lock',
      'a/b/c-0000111122223333'
    ]
    Dir.mktmpdir do |dir|
      (files + garbage).each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      wallets = Zold::TreeWallets.new(dir)
      assert_equal(files.count, wallets.count)
    end
  end
end
