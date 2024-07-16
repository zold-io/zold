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
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/node/entrance'
require_relative '../../lib/zold/node/pipeline'
require_relative '../../lib/zold/commands/pay'

# ENTRANCE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
class TestEntrance < Zold::Test
  def test_pushes_wallet
    sid = Zold::Id::ROOT
    tid = Zold::Id.new
    body = FakeHome.new(log: fake_log).run do |home|
      source = home.create_wallet(sid)
      target = home.create_wallet(tid)
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: fake_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, '19.99', 'testing'
        ]
      )
      File.read(source.path)
    end
    FakeHome.new(log: fake_log).run do |home|
      source = home.create_wallet(sid)
      target = home.create_wallet(tid)
      ledger = File.join(home.dir, 'ledger.csv')
      e = Zold::Entrance.new(
        home.wallets,
        Zold::Pipeline.new(home.remotes, home.copies(source).root, 'x', ledger: ledger),
        log: fake_log
      )
      modified = e.push(source.id, body)
      assert_equal(2, modified.count)
      assert_equal(Zold::Amount.new(zld: -19.99), source.balance)
      assert_equal(Zold::Amount.new(zld: 19.99), target.balance)
      assert(modified.include?(sid))
      assert(modified.include?(tid))
      assert_equal(1, File.read(ledger).split("\n").count)
    end
  end

  def test_renders_json
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      e = Zold::Entrance.new(home.wallets, Zold::Pipeline.new(home.remotes, home.copies.root, 'x'), log: fake_log)
      e.push(wallet.id, File.read(wallet.path))
      assert(e.to_json[:history].include?(wallet.id.to_s))
      assert(!e.to_json[:speed].negative?)
    end
  end
end
