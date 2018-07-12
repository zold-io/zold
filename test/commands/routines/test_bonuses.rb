=======
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
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../fake_home'
require_relative '../../node/fake_node'
require_relative '../../../lib/zold/node/farm.rb'
require_relative '../../../lib/zold/commands/push'
require_relative '../../../lib/zold/commands/pay'
require_relative '../../../lib/zold/commands/routines/bonuses.rb'

# Bonuses test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestBonuses < Minitest::Test
  def test_pays_bonuses
    FakeHome.new.run do |home|
      FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
        bank = home.create_wallet
        Zold::Pay.new(wallets: home.wallets, remotes: home.remotes, log: test_log).run(
          ['pay', home.create_wallet.id.to_s, bank.id.to_s, '100', '--force', '--private-key=id_rsa']
        )
        assert_equal(Zold::Amount.new(zld: 100.0), bank.balance)
        opts = {
          'ignore-score-weakness' => true,
          'routine-immediately' => true,
          'private-key' => 'id_rsa',
          'bonus-wallet' => bank.id.to_s,
          'bonus-amount' => 1,
          'bonus-time' => 0
        }
        score = Zold::Score.new(
          time: Time.now, host: 'fake-node.local', port: 999, invoice: 'NOPREFIX@ffffffffffffffff', strength: 1
        )
        16.times { score = score.next }
        remotes = home.remotes
        remotes.add('localhost', port)
        remotes.add(score.host, score.port)
        stub_request(:get, "http://#{score.host}:#{score.port}/").to_return(
          status: 200,
          body: {
            version: Zold::VERSION,
            score: score.to_h
          }.to_json
        )
        Zold::Routines::Bonuses.new(
          opts, home.wallets, remotes, home.copies(bank).root,
          Zold::Farm::Empty.new, log: test_log
        ).exec
        assert_equal(Zold::Amount.new(zld: 99.0), bank.balance)
      end
    end
  end
end
