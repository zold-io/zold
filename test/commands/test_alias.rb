# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/commands/alias'

class TestAlias < Zold::Test
  # alias set <wallet> <alias>
  # @todo #322:30min Implement the set command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_set_writes_alias_to_the_alias_file
    skip
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      Zold::Alias.new(wallets: home.wallets, log: fake_log).run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
    end
  end

  # alias remove <alias>
  # @todo #322:30min Implement the remove command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_remove_removes_the_alias_from_the_alias_file
    skip
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: fake_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
      cmd.run(%w[remove my-alias])
      assert_empty read_alias_file(home)
    end
  end

  # alias show <alias>
  # @todo #322:30min Implement the show command and unskip this test.
  #  The syntax is already documented in the alias command in the help.
  def test_show_prints_out_the_aliased_wallet_id
    skip
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      cmd = Zold::Alias.new(wallets: home.wallets, log: fake_log)
      cmd.run(%W[set #{wallet.id} my-alias])
      assert_equal read_alias_file(home), %W[my-alias #{wallet.id}]
      stdout, = capture_io { cmd.run(%w[show my-alias]) }
      assert_match wallet.id.to_s, stdout
    end
  end

  private

  def read_alias_file(home)
    File.read(File.join(home.dir, 'aliases')).split
  end
end
