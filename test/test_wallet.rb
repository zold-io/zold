# Copyright (c) 2018 Zerocracy, Inc.
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
require_relative '../lib/zold/key.rb'
require_relative '../lib/zold/id.rb'
require_relative '../lib/zold/wallet.rb'
require_relative '../lib/zold/amount.rb'

# Wallet test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
class TestWallet < Minitest::Test
  def test_adds_transaction
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'source.xml')
      wallet = Zold::Wallet.new(file)
      wallet.init(Zold::Id.new, Zold::Key.new('fixtures/id_rsa.pub'))
      amount = Zold::Amount.new(zld: 39.99)
      wallet.sub(amount, 100, Zold::Key.new('fixtures/id_rsa'))
      assert(
        wallet.balance == amount.mul(-1),
        "#{wallet.balance} is not equal to #{amount.mul(-1)}"
      )
    end
  end

  def test_initializes_it
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'source.xml')
      wallet = Zold::Wallet.new(file)
      id = Zold::Id.new.to_s
      wallet.init(id, Zold::Key.new('fixtures/id_rsa.pub'))
      assert(
        wallet.id == id,
        "#{wallet.id} is not equal to #{id}"
      )
    end
  end
end
