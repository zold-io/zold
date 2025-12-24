# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative 'test__helper'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/cached_wallets'
require_relative '../lib/zold/amount'

# CachedWallets test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestCachedWallets < Zold::Test
  def test_adds_wallet
    Dir.mktmpdir do |dir|
      wallets = Zold::CachedWallets.new(Zold::Wallets.new(dir))
      id = Zold::Id.new
      first = nil
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(1, wallets.all.count)
        first = wallet
      end
      wallets.acq(id) do |wallet|
        assert_equal(first, wallet)
      end
    end
  end

  def test_flushes_correctly
    Dir.mktmpdir do |dir|
      wallets = Zold::CachedWallets.new(Zold::Wallets.new(dir))
      id = Zold::Id.new
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      body = wallets.acq(id, exclusive: true) do |wallet|
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        File.read(wallet.path)
      end
      wallets.acq(id, exclusive: true) do |wallet|
        wallet.sub(Zold::Amount.new(zld: 1.0), "NOPREFIX@#{Zold::Id.new}", key)
      end
      assert_equal(1, wallets.acq(id, &:txns).count)
      wallets.acq(id, exclusive: true) do |wallet|
        File.write(wallet.path, body)
      end
      assert_equal(0, wallets.acq(id, &:txns).count)
    end
  end
end
