# frozen_string_literal: true

# Copyright (c) 2018-2025 Zerocracy
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
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../upgrades/delete_banned_wallets'
require_relative '../fake_home'

# Delete banned wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestDeleteBannedWallets < Zold::Test
  def test_delete_them
    id = Zold::Id.new(Zold::Id::BANNED[0])
    FakeHome.new(log: fake_log).run do |home|
      home.create_wallet(id)
      FileUtils.mkdir_p(File.join(home.dir, 'a/b/c'))
      File.rename(
        File.join(home.dir, "#{id}#{Zold::Wallet::EXT}"),
        File.join(home.dir, "a/b/c/#{id}#{Zold::Wallet::EXT}")
      )
      Zold::DeleteBannedWallets.new(home.dir, fake_log).exec
      assert(File.exist?(File.join(home.dir, "a/b/c/#{id}#{Zold::Wallet::EXT}-banned")))
    end
  end
end
