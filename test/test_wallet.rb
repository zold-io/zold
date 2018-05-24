# Copyright (c) 2018 Yegor Bugayenko
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
require 'tmpdir'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/amount'
require_relative '../lib/zold/commands/pay'

# Wallet test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  def test_adds_transaction
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      assert(
        wallet.balance == amount * -3,
        "#{wallet.balance} is not equal to #{amount * -3}"
      )
    end
  end

  def test_adds_transaction_and_reads_back
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      txn = wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.add(txn.inverse(wallet.id))
      assert(!Zold::Wallet.new(wallet.path).txns[0].sign.end_with?("\n"))
    end
  end

  def test_iterates_income_transactions
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1, Time.now, Zold::Amount.new(zld: 39.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      wallet.add(
        Zold::Txn.new(
          2, Time.now, Zold::Amount.new(zld: 14.95),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      sum = Zold::Amount::ZERO
      wallet.income do |t|
        sum += t.amount
      end
      assert(
        sum == Zold::Amount.new(coins: 921_740_246),
        "#{sum} is not equal to #{Zold::Amount.new(zld: 54.94)}"
      )
    end
  end
end
