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
require_relative '../lib/zold/key.rb'
require_relative '../lib/zold/id.rb'
require_relative '../lib/zold/wallet.rb'
require_relative '../lib/zold/amount.rb'
require_relative '../lib/zold/commands/send.rb'

# Wallet test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  def test_adds_transaction
    Dir.mktmpdir 'test' do |dir|
      wallet = wallet(dir)
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      assert(
        wallet.version.zero?,
        "Wallet version #{wallet.version} is not equal to zero"
      )
      wallet.sub(amount, Zold::Id.new, key)
      assert(
        wallet.version == 1,
        "Wallet version #{wallet.version} is not equal to 1"
      )
      wallet.sub(amount, Zold::Id.new, key)
      assert(
        wallet.version == 2,
        "Wallet version #{wallet.version} is not equal to 2"
      )
      wallet.sub(amount, Zold::Id.new, key)
      assert(
        wallet.version == 3,
        "Wallet version #{wallet.version} is not equal to 3"
      )
      assert(
        wallet.balance == amount.mul(-3),
        "#{wallet.balance} is not equal to #{amount.mul(-3)}"
      )
    end
  end

  def test_initializes_it
    Dir.mktmpdir 'test' do |dir|
      pkey = Zold::Key.new(file: 'fixtures/id_rsa.pub')
      Dir.chdir(dir) do
        file = File.join(dir, 'source')
        wallet = Zold::Wallet.new(file)
        id = Zold::Id.new.to_s
        wallet.init(id, pkey)
        assert(
          wallet.id == id,
          "#{wallet.id} is not equal to #{id}"
        )
      end
    end
  end

  def test_iterates_income_transactions
    Dir.mktmpdir 'test' do |dir|
      wallet = wallet(dir)
      wallet.add(
        id: 1,
        date: Time.now, amount: Zold::Amount.new(zld: 39.99),
        beneficiary: Zold::Id.new
      )
      wallet.add(
        id: 2,
        date: Time.now, amount: Zold::Amount.new(zld: 14.95),
        beneficiary: Zold::Id.new
      )
      sum = Zold::Amount::ZERO
      wallet.income do |t|
        sum += t[:amount]
      end
      assert(
        sum == Zold::Amount.new(coins: 921_740_246),
        "#{sum} is not equal to #{Zold::Amount.new(zld: 54.94)}"
      )
    end
  end

  def test_checks_transaction
    Dir.mktmpdir 'test' do |dir|
      payer = wallet(dir)
      receiver = wallet(dir)
      amount = Zold::Amount.new(zld: 14.95)
      txn = Zold::Send.new(
        payer: payer, receiver: receiver,
        amount: amount,
        pvtkey: Zold::Key.new(file: 'fixtures/id_rsa')
      ).run
      assert payer.check(txn, amount, receiver.id)
    end
  end

  private

  def wallet(dir)
    id = Zold::Id.new
    file = File.join(dir, id.to_s)
    wallet = Zold::Wallet.new(file)
    wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
    wallet
  end
end
