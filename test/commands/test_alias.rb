# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/zold/commands/alias'
require_relative '../fake_home'
require_relative '../test__helper'

class TestAlias < Zold::Test
  # alias set <wallet> <alias>
  # @todo #322:30min Implement the set command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_set_writes_alias_to_the_alias_file
    skip('the alias command is not implemented yet')
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      Zold::Alias.new(wallets: home.wallets, log: fake_log).run(%W[set #{wallet.id} my-alias])
      assert_equal(read(home), %W[my-alias #{wallet.id}])
    end
  end

  # alias remove <alias>
  # @todo #322:30min Implement the remove command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_remove_removes_the_alias
    skip('the alias command is not implemented yet')
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: fake_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal(read(home), %W[my-alias #{wallet.id}])
      cmd.run(%w[remove my-alias])
      assert_empty(read(home))
    end
  end

  # alias show <alias>
  # @todo #322:30min Implement the show command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_show_prints_out_the_aliased_wallet_id
    skip('the alias command is not implemented yet')
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: fake_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal(read(home), %W[my-alias #{wallet.id}])
      stdout, = capture_io { cmd.run(%w[show my-alias]) }
      assert_match(wallet.id.to_s, stdout)
    end
  end

  private

  def read(home)
    File.read(File.join(home.dir, 'aliases')).split
  end
end
