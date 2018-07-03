require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/commands/alias'

class TestAlias < Minitest::Test
  # alias set <wallet> <alias>
  def test_set_writes_alias_to_the_alias_file
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      assert_raises NotImplementedError do
        Zold::Alias.new(wallets: home.wallets, log: test_log).run(['set', wallet.id.to_s, 'my-alias'])
      end
    end
  end

  # alias remove <alias>
  def test_remove_removes_the_alias_from_the_alias_file
    FakeHome.new.run do |home|
      assert_raises NotImplementedError do
        Zold::Alias.new(wallets: home.wallets, log: test_log).run(['remove', 'my-alias'])
      end
    end
  end

  # alias show <alias>
  def test_show_prints_out_the_aliased_wallet_id
    FakeHome.new.run do |home|
      assert_raises NotImplementedError do
        Zold::Alias.new(wallets: home.wallets, log: test_log).run(['show', 'my-alias'])
      end
    end
  end
end
