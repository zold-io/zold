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
require 'webmock/minitest'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/json_page'
require_relative '../../lib/zold/commands/pull'
require_relative '../../lib/zold/home'

# PUSH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPull < Zold::Test
  def test_pull_wallet
    FakeHome.new(log: test_log).run do |fake_home|
      remotes = fake_home.remotes
      remotes.add('localhost', 4096)
      json = fake_home.create_wallet_json
      hash = Zold::JsonPage.new(json).to_hash
      id = hash['id']
      stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 200, body: json)
      stub_request(:get, "http://localhost:4096/wallet/#{id}.bin").to_return(status: 200, body: hash['body'])
      home = ::Zold::Home.new(wallets: fake_home.wallets, remotes: remotes, copies: fake_home.copies.root.to_s)
      Zold::Pull.new(home: home, log: test_log).run(
        ['--ignore-this-stupid-option', 'pull', id.to_s, '--tolerate-edges', '--tolerate-quorum=1']
      )
      home.wallets.acq(Zold::Id.new(id)) do |wallet|
        assert(wallet.exists?)
      end
    end
  end

  def test_fails_when_only_edge_nodes
    FakeHome.new(log: test_log).run do |fake_home|
      remotes = fake_home.remotes
      remotes.add('localhost', 4096)
      json = fake_home.create_wallet_json
      hash = Zold::JsonPage.new(json).to_hash
      id = hash['id']
      stub_request(:get, "http://localhost:4096/wallet/#{id}").to_return(status: 200, body: json)
      stub_request(:get, "http://localhost:4096/wallet/#{id}.bin").to_return(status: 200, body: hash['body'])
      home = ::Zold::Home.new(wallets: fake_home.wallets, remotes: remotes, copies: fake_home.copies.root.to_s)
      assert_raises Zold::Fetch::EdgesOnly do
        Zold::Pull.new(home: home, log: test_log).run(
          ['--ignore-this-stupid-option', 'pull', id.to_s]
        )
      end
    end
  end
end
