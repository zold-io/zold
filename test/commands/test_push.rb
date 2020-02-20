# frozen_string_literal: true

# Copyright (c) 2018-2020 Zerocracy, Inc.
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
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/push'

# PUSH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPush < Zold::Test
  def test_pushes_wallet
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      Zold::Push.new(wallets: home.wallets, remotes: remotes, log: test_log).run(
        ['--ignore-this-stupid-option', 'push', wallet.id.to_s, '--tolerate-edges', '--tolerate-quorum=1']
      )
    end
  end

  def test_pushes_multiple_wallets
    log = TestLogger.new(test_log)
    FakeHome.new(log: log).run do |home|
      wallet_a = home.create_wallet
      wallet_b = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet_a.id}").to_return(status: 304)
      stub_request(:put, "http://localhost:80/wallet/#{wallet_b.id}").to_return(status: 304)
      Zold::Push.new(wallets: home.wallets, remotes: remotes, log: log).run(
        ['--tolerate-edges', '--tolerate-quorum=1', '--threads=2', 'push', wallet_a.id.to_s, wallet_b.id.to_s]
      )
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      assert_raises Zold::Push::EdgesOnly do
        Zold::Push.new(wallets: home.wallets, remotes: remotes, log: test_log).run(
          ['push', wallet.id.to_s]
        )
      end
    end
  end

  def test_fails_when_only_one_node
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      remotes = home.remotes
      remotes.add('localhost', 80)
      stub_request(:put, "http://localhost:80/wallet/#{wallet.id}").to_return(status: 304)
      assert_raises Zold::Push::NoQuorum do
        Zold::Push.new(wallets: home.wallets, remotes: remotes, log: test_log).run(
          ['push', wallet.id.to_s, '--tolerate-edges']
        )
      end
    end
  end
end
