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
require 'tmpdir'
require 'json'
require 'time'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/score'
require_relative '../../lib/zold/commands/fetch'

# FETCH test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestFetch < Minitest::Test
  def test_fetches_wallet
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      stub_request(:get, "http://localhost:80/wallet/#{wallet.id}").to_return(
        status: 200,
        body: {
          'score': Zold::Score::ZERO.to_h,
          'body': File.read(wallet.path),
          'mtime': Time.now.utc.iso8601
        }.to_json
      )
      stub_request(:get, "http://localhost:81/wallet/#{wallet.id}").to_return(
        status: 404
      )
      remotes = home.remotes
      remotes.add('localhost', 80)
      remotes.add('localhost', 81)
      copies = home.copies(wallet)
      Zold::Fetch.new(wallets: home.wallets, copies: copies.root, remotes: remotes, log: test_log).run(
        ['fetch', '--ignore-score-weakness', wallet.id.to_s]
      )
      assert_equal(copies.all[0][:name], '1')
      assert_equal(copies.all[0][:score], 0)
    end
  end

  def setup_trust_test(home)
    wallet = home.create_wallet
    stub_request(:get, "http://localhost:80/wallet/#{wallet.id}").to_return(
      status: 200,
      body: {
        'score': Zold::Score.new(Time.now, 'localhost', 80,
          'NOPREFIX@ffffffffffffffff', strength: 10),
        'body': File.read(wallet.path),
        'mtime': Time.now.utc.iso8601
      }.to_json
    )
    stub_request(:get, "http://localhost:81/wallet/#{wallet.id}").to_return(
      status: 200,
      body: {
        'score': Zold::Score.new(Time.now, 'localhost', 80,
          'NOPREFIX@ffffffffffffffff', strength: 20),
        'body': File.read(wallet.path),
        'mtime': Time.now.utc.iso8601
      }.to_json
    )
    remotes = home.remotes
    remotes.add('localhost', 80)
    remotes.add('localhost', 81)
    copies = home.copies(wallet)

    [wallet, copies, remotes]
  end

  def test_fetches_only_one_remote_with_enough_trust
    FakeHome.new.run do |home|
      wallet, copies, remotes = setup_trust_test(home)
      Zold::Fetch.new(wallets: home.wallets, copies: copies.root,
                      remotes: remotes, log: test_log)
          .run(['fetch', wallet.id.to_s, '--trust 10'])
      assert_equal(copies.count, '1')
      assert_equal(copies.all[0][:score], 10)
    end
  end

  def test_fetches_all_remotes_if_trust_is_not_enough
    FakeHome.new.run do |home|
      wallet, copies, remotes = setup_trust_test(home)
      Zold::Fetch.new(wallets: home.wallets, copies: copies.root,
                      remotes: remotes, log: test_log)
          .run(['fetch', wallet.id.to_s, '--trust 40'])
      assert_equal(copies.count, '2')
    end
  end
end
