# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy, Inc.
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
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/taxes'

# TAXES test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestTaxes < Zold::Test
  def test_pays_taxes
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      wallet = home.create_wallet
      fund = Zold::Amount.new(zld: 19.99)
      10.times do |i|
        wallet.add(
          Zold::Txn.new(
            i + 1,
            Time.now - 24 * 60 * 60 * 365 * 300,
            fund,
            'NOPREFIX', Zold::Id.new, '-'
          )
        )
      end
      remotes = home.remotes
      score = Zold::Score.new(host: 'localhost', port: 80, strength: 1, invoice: 'NOPREFIX@0000000000000000')
      10.times { score = score.next }
      remotes.add(score.host, score.port)
      stub_request(:get, "http://#{score.host}:#{score.port}/").to_return(
        status: 200,
        body: {
          score: score.to_h
        }.to_json
      )
      before = wallet.balance
      tax = Zold::Tax.new(wallet, ignore_score_weakness: true)
      debt = tax.debt
      Zold::Taxes.new(wallets: wallets, remotes: remotes, log: test_log).run(
        ['taxes', '--private-key=fixtures/id_rsa', '--ignore-score-weakness', 'pay', wallet.id.to_s]
      )
      wallet.flush
      assert(tax.paid.positive?, tax.paid)
      assert_equal((before - debt).to_zld(6), wallet.balance.to_zld(6))
    end
  end
end
