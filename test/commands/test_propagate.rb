# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/commands/propagate'
require_relative '../../lib/zold/commands/pay'
require_relative '../../lib/zold/home'

# PROPAGATE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPropagate < Zold::Test
  def test_propagates_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      friend = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(home: Zold::Home.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes), log: test_log).run(
        ['pay', wallet.id.to_s, friend.id.to_s, amount.to_zld, '--force', '--private-key=fixtures/id_rsa']
      )
      Zold::Propagate.new(wallets: home.wallets, log: test_log).run(
        ['merge', wallet.id.to_s]
      )
      assert(amount, friend.balance)
      assert(1, friend.txns.count)
      assert('', friend.txns[0].sign)
    end
  end
end
