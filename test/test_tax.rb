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
require 'time'
require_relative 'fake_home'
require_relative '../lib/zold/id'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/tax'
require_relative '../lib/zold/key'
require_relative '../lib/zold/amount'
require_relative '../lib/zold/prefixes'
require_relative '../lib/zold/score'

# Tax test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestTax < Minitest::Test
  def test_calculates_tax_for_one_year
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      tax = Zold::Tax.new(wallet)
      assert_equal(Zold::Amount.new(coins: 61_320), tax.debt)
    end
  end

  def test_checks_existence_of_duplicates
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      target = home.create_wallet
      invoice = "#{Zold::Prefixes.new(target).create}@#{target.id}"
      tax = Zold::Tax.new(wallet)
      score = Zold::Score.new(Time.now, 'localhost', 80, invoice)
      tax.pay(Zold::Key.new(file: 'fixtures/id_rsa'), score)
      assert(
        tax.exists?(
          Zold::Txn.new(
            2,
            Time.now,
            Zold::Amount.new(zld: 10.99),
            'AAPREFIX', target.id, tax.details(score)
          )
        )
      )
      assert(
        !tax.exists?(
          Zold::Txn.new(
            2,
            Time.now,
            Zold::Amount.new(zld: 10.99),
            'NOPREFIX', target.id, '-'
          )
        )
      )
    end
  end
end
