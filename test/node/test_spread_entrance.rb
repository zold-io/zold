# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
require_relative 'fake_node'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/entrance'
require_relative '../../lib/zold/node/spread_entrance'
require_relative 'fake_entrance'

# SpreadEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestSpreadEntrance < Zold::Test
  def test_renders_json
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet(Zold::Id.new)
      Zold::SpreadEntrance.new(
        Zold::Entrance.new(home.wallets, home.remotes, home.copies(wallet).root, 'x', log: test_log),
        home.wallets, home.remotes, 'x', log: test_log
      ).start do |e|
        assert_equal(0, e.to_json[:modified])
      end
    end
  end

  def test_ignores_duplicates
    FakeHome.new(log: test_log).run do |home|
      FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
        wallet = home.create_wallet
        remotes = home.remotes
        remotes.add('localhost', port)
        Zold::SpreadEntrance.new(FakeEntrance.new, home.wallets, remotes, 'x', log: test_log).start do |e|
          8.times { e.push(wallet.id, IO.read(wallet.path)) }
          assert(e.to_json[:modified] < 2, "It's too big: #{e.to_json[:modified]}")
        end
      end
    end
  end
end
