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
require 'webmock/minitest'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/taxes'

# TAXES test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestTaxes < Minitest::Test
  def test_pays_taxes
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallet = wallets.find(id)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - 24 * 60 * 365 * 20,
          Zold::Amount.new(zld: 19.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      remotes = Zold::Remotes.new(File.join(dir, 'a/remotes'))
      remotes.clean
      zero = Zold::Score::ZERO
      remotes.add(zero.host, zero.port)
      stub_request(:get, "http://#{zero.host}:#{zero.port}/").to_return(
        status: 200,
        body: {
          score: zero.to_h
        }.to_json
      )
      Zold::Taxes.new(
        wallets: wallets, remotes: remotes
      ).run(['taxes', '--private-key=fixtures/id_rsa', id.to_s])
      assert_equal(Zold::Amount.new(coins: 335_376_547), wallet.balance)
    end
  end
end
