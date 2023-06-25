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
require 'webmock/minitest'
require 'threads'
require 'shellwords'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/json_page'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/pay'

# PAY test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPay < Zold::Test
  def test_sends_from_wallet_to_wallet
    FakeHome.new(log: test_log).run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal(amount * -1, source.balance)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--private-key=fixtures/id_rsa',
          target.id.to_s, source.id.to_s, amount.to_zld, 'Refund'
        ]
      )
      source.flush
      assert_equal(Zold::Amount::ZERO, source.balance)
    end
  end

  def test_pay_without_invoice
    FakeHome.new(log: test_log).run do |home|
      remotes = home.remotes
      remotes.add('localhost', 4096)
      json = home.create_wallet_json
      hash = Zold::JsonPage.new(json).to_hash
      id = hash['id']
      stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 200, body: json)
      stub_request(:get, "http://localhost:4096/wallet/#{id}.bin").to_return(status: 200, body: hash['body'])
      home.wallets.acq(Zold::Id.new(id)) { |w| File.delete(w.path) }
      source = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: remotes, log: test_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa', '--tolerate-edges', '--tolerate-quorum=1',
          source.id.to_s, id, amount.to_zld, 'For the car'
        ]
      )
      assert_equal(amount * -1, source.balance)
    end
  end

  def test_pay_with_keygap
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 2.0)
      Tempfile.open do |f|
        pem = IO.read('fixtures/id_rsa')
        keygap = pem[100..120]
        IO.write(f, pem.gsub(keygap, '*' * keygap.length))
        Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
          [
            'pay', '--force', "--private-key=#{Shellwords.escape(f.path)}",
            "--keygap=#{Shellwords.escape(keygap)}",
            wallet.id.to_s, 'NOPREFIX@dddd0000dddd0000', amount.to_zld, '-'
          ]
        )
      end
      assert_equal(amount * -1, wallet.balance)
    end
  end

  def test_pay_in_many_threads
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 2.0)
      wallets = home.wallets
      Threads.new(10).assert do
        Zold::Pay.new(wallets: wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
          [
            'pay', '--force', '--private-key=fixtures/id_rsa',
            wallet.id.to_s, 'NOPREFIX@dddd0000dddd0000', amount.to_zld, '-'
          ]
        )
      end
      assert_equal(amount * -10, wallet.balance)
    end
  end

  def test_sends_from_root_wallet
    FakeHome.new(log: test_log).run do |home|
      source = home.create_wallet(Zold::Id::ROOT)
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal(amount * -1, source.balance)
    end
  end

  def test_sends_from_normal_wallet
    FakeHome.new(log: test_log).run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      source.add(
        Zold::Txn.new(
          1, Time.now, amount,
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'here is the refund'
        ]
      )
      assert_equal(Zold::Amount::ZERO, source.balance)
    end
  end

  def test_notifies_about_tax_status
    FakeHome.new(log: test_log).run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      accumulating_log = test_log.dup
      class << accumulating_log
        attr_accessor :info_messages

        def info(message)
          (@info_messages ||= []) << message
        end
      end
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: accumulating_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          '--ignore-score-weakness', '--pay-taxes-anyway',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal accumulating_log.info_messages.grep(/^The tax debt/).size, 1,
        'No info_messages notified user of tax debt'
    end
  end

  def test_pays_and_taxes
    FakeHome.new(log: test_log).run do |home|
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
      score = Zold::Score.new(host: 'localhost', port: 80, strength: 1, invoice: 'NOPREFIX@0000000000000000')
      10.times { score = score.next }
      remotes = home.remotes
      remotes.add(score.host, score.port)
      stub_request(:get, "http://#{score.host}:#{score.port}/").to_return(
        status: 200,
        body: {
          score: score.to_h
        }.to_json
      )
      before = wallet.balance
      target = home.create_wallet
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: remotes, log: test_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          '--ignore-score-weakness',
          wallet.id.to_s, target.id.to_s, fund.to_zld, 'For the car'
        ]
      )
      wallet.flush
      assert(before.to_zld(6) != wallet.balance.to_zld(6))
    end
  end
end
