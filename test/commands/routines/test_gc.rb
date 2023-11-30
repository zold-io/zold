# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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
require_relative '../../../lib/zold/wallets'
require_relative '../../../lib/zold/commands/routines/gc'

# Gc test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestGc < Zold::Test
  def test_collects_garbage
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      opts = { 'routine-immediately' => true, 'gc-age' => 0 }
      assert_equal(1, wallets.count)
      routine = Zold::Routines::Gc.new(opts, wallets, log: test_log)
      routine.exec
      assert_equal(0, wallets.count)
    end
  end

  def test_doesnt_touch_non_empty_wallets
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      opts = { 'routine-immediately' => true, 'gc-age' => 0 }
      routine = Zold::Routines::Gc.new(opts, wallets, log: test_log)
      routine.exec
      assert_equal(1, wallets.count)
    end
  end

  def test_doesnt_touch_fresh_wallets
    FakeHome.new(log: test_log).run do |home|
      wallets = home.wallets
      home.create_wallet
      opts = { 'routine-immediately' => true, 'gc-age' => 60 * 60 }
      routine = Zold::Routines::Gc.new(opts, wallets, log: test_log)
      routine.exec
      assert_equal(1, wallets.count)
    end
  end
end
