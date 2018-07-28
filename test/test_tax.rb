# frozen_string_literal: true

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
require_relative 'test__helper'
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
  def test_print_fee
    test_log.info("Fee in zents: #{Zold::Tax::FEE_TXN_HOUR.to_i}")
  end

  def test_calculates_tax_for_one_year
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      tax = Zold::Tax.new(wallet)
      assert(tax.debt > Zold::Amount.new(coins: 1_006_523_000))
      assert(tax.debt < Zold::Amount.new(coins: 1_006_524_999))
    end
  end

  def test_calculates_debt
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      score = Zold::Score.new(
        time: Time.now, host: 'localhost', port: 80, invoice: 'NOPREFIX@cccccccccccccccc',
        suffixes: %w[A B C D E F G H I J K L M N O P Q R S T U V]
      )
      tax = Zold::Tax.new(wallet)
      tax.pay(Zold::Key.new(file: 'fixtures/id_rsa'), score)
      assert(tax.debt > Zold::Amount::ZERO)
    end
  end

  def test_takes_tax_payment_into_account
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now,
          Zold::Amount.new(coins: 95_596_800),
          'NOPREFIX', Zold::Id.new('912ecc24b32dbe74'),
          'TAXES 6 5b5a21a9 b2.zold.io 1000 DCexx0hG 912ecc24b32dbe74 \
386d4a ec9eae 306e3d 119d073 1c00dba 1376703 203589 5b55f7'
        )
      )
      tax = Zold::Tax.new(wallet)
      assert(tax.debt < Zold::Amount::ZERO)
    end
  end

  def test_checks_existence_of_duplicates
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 60 * 365,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      target = home.create_wallet
      invoice = "#{Zold::Prefixes.new(target).create}@#{target.id}"
      tax = Zold::Tax.new(wallet)
      score = Zold::Score.new(
        time: Time.now, host: 'localhost', port: 80, invoice: invoice,
        suffixes: %w[A B C D E F G H I J K L M N O P Q R S T U V]
      )
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
