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
require 'json'
require 'time'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../fake_home'
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
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      first = home.create_wallet
      File.write(first.path, File.read(wallet.path))
      second = home.create_wallet
      File.write(second.path, File.read(wallet.path))
      Zold::Pay.new(wallets: home.wallets, log: $log).run(
        ['pay', wallet.id.to_s, second.id.to_s, '14.95', '--force', '--private-key=fixtures/id_rsa']
      )
      copies = home.copies(wallet)
      copies.add(File.read(first.path), 'host-1', 80, 5)
      copies.add(File.read(second.path), 'host-2', 80, 5)
      diff = Zold::Diff.new(wallets: home.wallets, copies: copies.root, log: $log).run(
        ['diff', wallet.id.to_s]
      )
      assert(diff.include?('-0001;'))
    end
  end
end
