# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'time'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/pay'
require_relative '../../lib/zold/commands/diff'

# DIFF test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestDiff < Zold::Test
  def test_diff_with_copies
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      first = home.create_wallet
      File.write(first.path, File.read(wallet.path))
      second = home.create_wallet
      File.write(second.path, File.read(wallet.path))
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: fake_log).run(
        ['pay', wallet.id.to_s, "NOPREFIX@#{Zold::Id.new}", '14.95', '--force', '--private-key=fixtures/id_rsa']
      )
      copies = home.copies(wallet)
      copies.add(File.read(first.path), 'host-1', 80, 5)
      copies.add(File.read(second.path), 'host-2', 80, 5)
      diff = Zold::Diff.new(wallets: home.wallets, copies: copies.root, log: fake_log).run(
        ['diff', wallet.id.to_s]
      )
      assert_includes(diff, '-0001;', diff)
    end
  end
end
