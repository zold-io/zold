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
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallet = wallets.find(id)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      remotes = Zold::Remotes.new(File.join(dir, 'remotes.csv'))
      remotes.clean
      stub_request(:get, "http://fake-1/wallet/#{id}").to_return(
        status: 200,
        body: {
          'score': Zold::Score::ZERO.to_h,
          'body': File.read(wallet.path)
        }.to_json
      )
      stub_request(:get, "http://fake-2/wallet/#{id}").to_return(
        status: 404
      )
      remotes.add('fake-1', 80)
      remotes.add('fake-2', 80)
      copies = Zold::Copies.new(File.join(dir, "copies/#{id}"))
      Zold::Fetch.new(wallets: wallets, copies: copies.root, remotes: remotes, log: test_log).run(
        ['fetch', '--ignore-score-weakness', id.to_s]
      )
      assert_equal(copies.all[0][:name], '1')
      assert_equal(copies.all[0][:score], 0)
    end
  end

  def test_fetches_empty_wallet
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      remotes = Zold::Remotes.new(File.join(dir, 'remotes.csv'))
      remotes.clean
      stub_request(:get, "http://fake-1/wallet/#{id}").to_return(
        status: 200,
        body: {
          'score': Zold::Score::ZERO.to_h,
          'body': 'the body'
        }.to_json
      )
      remotes.add('fake-1', 80)
      copies = Zold::Copies.new(File.join(dir, "copies/#{id}"))
      Zold::Fetch.new(
        wallets: wallets, copies: copies.root, remotes: remotes, log: test_log
      ).run(['fetch', id.to_s])
      assert_equal(copies.all[0][:name], '1')
      assert_equal(copies.all[0][:score], 0)
    end
  end
end
