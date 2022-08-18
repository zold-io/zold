# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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
require 'time'
require 'threads'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/commands/clean'

# CLEAN test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestClean < Zold::Test
  def test_cleans_copies
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      copies.add('a1', 'host-1', 80, 1, time: Time.now - 26 * 60 * 60)
      copies.add('a2', 'host-2', 80, 2, time: Time.now - 26 * 60 * 60)
      Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: test_log).run(['clean', wallet.id.to_s])
      assert(copies.all.empty?)
    end
  end

  def test_clean_no_copies
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: test_log).run(['clean'])
      assert(copies.all.empty?)
    end
  end

  def test_cleans_empty_wallets
    FakeHome.new(log: test_log).run do |home|
      Zold::Clean.new(wallets: home.wallets, copies: File.join(home.dir, 'c'), log: test_log).run(['clean'])
    end
  end

  def test_cleans_copies_in_threads
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      copies.add(IO.read(wallet.path), 'host-2', 80, 2, time: Time.now)
      Threads.new(20).assert do
        Zold::Clean.new(wallets: home.wallets, copies: copies.root, log: test_log).run(['clean'])
      end
      assert_equal(1, copies.all.count)
    end
  end
end
