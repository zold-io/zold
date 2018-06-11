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
require_relative '../../test__helper'
require_relative '../../fake_home'
require_relative '../../../lib/zold/node/farm.rb'
require_relative '../../../lib/zold/commands/routines/bonuses.rb'

# Bonuses test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestBonuses < Minitest::Test
  def test_pays_bonuses
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      opts = {
        'routine-immediately' => true,
        'private-key' => 'fixtures/id_rsa',
        'bonus-wallet' => wallet.id.to_s,
        'bonus-amount' => 1
      }
      routine = Zold::Routines::Bonuses.new(
        opts, home.wallets, home.remotes, home.copies(wallet).root,
        Zold::Farm::Empty, log: test_log
      )
      routine.exec
    end
  end
end
