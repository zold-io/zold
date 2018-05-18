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
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/pay'
require_relative '../../lib/zold/commands/diff'

# DIFF test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestDiff < Minitest::Test
  def test_diff_with_copies
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      wallet = Zold::Wallet.new(File.join(dir, id.to_s))
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      first = Zold::Wallet.new(File.join(dir, 'copy-1'))
      File.write(first.path, File.read(wallet.path))
      second = Zold::Wallet.new(File.join(dir, 'copy-2'))
      File.write(second.path, File.read(wallet.path))
      Zold::Pay.new(
        wallets: Zold::Wallets.new(dir), log: $log
      ).run(['pay', id.to_s, second.id.to_s, '14.95', '--force', '--private-key=fixtures/id_rsa'])
      copies = Zold::Copies.new(File.join(dir, "copies/#{id}"))
      copies.add(File.read(first.path), 'host-1', 80, 5)
      copies.add(File.read(second.path), 'host-2', 80, 5)
      diff = Zold::Diff.new(
        wallets: Zold::Wallets.new(dir),
        copies: copies.root, log: $log
      ).run(['diff', id.to_s])
      assert(diff.include?('-0001;'))
    end
  end
end
