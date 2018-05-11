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
require_relative '../../lib/zold/wallet.rb'
require_relative '../../lib/zold/id.rb'
require_relative '../../lib/zold/copies.rb'
require_relative '../../lib/zold/key.rb'
require_relative '../../lib/zold/score.rb'
require_relative '../../lib/zold/patch.rb'
require_relative '../../lib/zold/commands/merge.rb'
require_relative '../../lib/zold/commands/pay.rb'

# MERGE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestMerge < Minitest::Test
  def test_merges_wallet
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      file = File.join(dir, id.to_s)
      wallet = Zold::Wallet.new(file)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      first = Zold::Wallet.new(File.join(dir, 'copy-1'))
      File.write(first.path, File.read(wallet.path))
      second = Zold::Wallet.new(File.join(dir, 'copy-2'))
      File.write(second.path, File.read(wallet.path))
      Zold::Pay.new(
        payer: first,
        receiver: second,
        amount: Zold::Amount.new(zld: 14.95),
        pvtkey: Zold::Key.new(file: 'fixtures/id_rsa')
      ).run(['--force'])
      copies = Zold::Copies.new(File.join(dir, 'copies'))
      copies.add(File.read(first.path), 'host-1', 80, 5)
      copies.add(File.read(second.path), 'host-2', 80, 5)
      Zold::Merge.new(wallet: wallet, copies: copies).run
    end
  end
end
