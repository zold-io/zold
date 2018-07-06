require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/commands/alias'

class TestAlias < Minitest::Test
  # alias set <wallet> <alias>
  def test_set_writes_alias_to_the_alias_file
    skip
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      Zold::Alias.new(wallets: home.wallets, log: test_log).run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
    end
  end

  # alias remove <alias>
  def test_remove_removes_the_alias_from_the_alias_file
    skip
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: test_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
      cmd.run(%w[remove my-alias])
      assert_empty read_alias_file(home)
    end
  end

  # alias show <alias>
  def test_show_prints_out_the_aliased_wallet_id
    skip
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: test_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
      stdout, = capture_io { cmd.run(%w[show my-alias]) }
      assert_match wallet.id.to_s, stdout
    end
  end

  private

  def read_alias_file(home)
    File.read(File.join(home.dir, 'aliases')).split(' ')
  end
end
