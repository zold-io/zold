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
require 'tmpdir'
require_relative '../test__helper'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/show'

# SHOW test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestShow < Zold::Test
  def test_checks_wallet_balance
    Dir.mktmpdir do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallets.acq(id) do |wallet|
        wallet.init(Zold::Id.new, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        balance = Zold::Show.new(wallets: wallets, copies: File.join(dir, 'c'), log: test_log).run(['show', id.to_s])
        assert_equal(Zold::Amount::ZERO, balance)
      end
    end
  end
end
