# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/commands/remove'

# REMOVE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemove < Zold::Test
  def test_removes_one_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      assert_equal(1, home.wallets.all.count)
      Zold::Remove.new(wallets: home.wallets, log: test_log).run(['remove', wallet.id.to_s])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_wallets
    FakeHome.new(log: test_log).run do |home|
      home.create_wallet
      home.create_wallet
      Zold::Remove.new(wallets: home.wallets, log: test_log).run(['remove'])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_no_wallets
    FakeHome.new(log: test_log).run do |home|
      Zold::Remove.new(wallets: home.wallets, log: test_log).run(['remove'])
      assert(home.wallets.all.empty?)
    end
  end

  def test_removes_absent_wallets
    FakeHome.new(log: test_log).run do |home|
      Zold::Remove.new(wallets: home.wallets, log: test_log).run(
        ['remove', '7654321076543210', '--force']
      )
      assert(home.wallets.all.empty?)
    end
  end
end
