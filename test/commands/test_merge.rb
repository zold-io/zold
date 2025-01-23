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
require 'tmpdir'
require 'time'
require 'webmock/minitest'
require 'zold/score'
require 'English'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/patch'
require_relative '../../lib/zold/commands/merge'
require_relative '../../lib/zold/commands/pay'

# MERGE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestMerge < Zold::Test
  def test_merges_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      first = home.create_wallet
      File.write(first.path, File.read(wallet.path))
      second = home.create_wallet
      File.write(second.path, File.read(wallet.path))
      Zold::Pay.new(wallets: home.wallets, copies: home.dir, remotes: home.remotes, log: fake_log).run(
        ['pay', wallet.id.to_s, "NOPREFIX@#{Zold::Id.new}", '14.95', '--force', '--private-key=fixtures/id_rsa']
      )
      copies = home.copies(wallet)
      copies.add(File.read(first.path), 'host-1', 80, 5)
      copies.add(File.read(second.path), 'host-2', 80, 5)
      modified = Zold::Merge.new(wallets: home.wallets, remotes: home.remotes, copies: copies.root, log: fake_log).run(
        ['merge', wallet.id.to_s]
      )
      assert(1, modified.count)
      assert(wallet.id, modified[0])
    end
  end

  def test_merges_with_a_broken_copy
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      copies = home.copies(wallet)
      copies.add(File.read(wallet.path), 'good-host', 80, 5)
      copies.add('some garbage', 'bad-host', 80, 5)
      modified = Zold::Merge.new(wallets: home.wallets, remotes: home.remotes, copies: copies.root, log: fake_log).run(
        ['merge', wallet.id.to_s]
      )
      assert(modified.empty?)
    end
  end

  def test_merges_a_copy_on_top
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet(Zold::Id::ROOT)
      copies = home.copies(wallet)
      copies.add(File.read(wallet.path), 'good-host', 80, 5)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(Zold::Amount.new(zld: 9.99), "NOPREFIX@#{Zold::Id.new}", key)
      Zold::Merge.new(wallets: home.wallets, remotes: home.remotes, copies: copies.root, log: fake_log).run(
        ['merge', wallet.id.to_s]
      )
      assert(!wallet.balance.zero?)
    end
  end

  def test_rejects_fake_positives_in_new_wallet
    FakeHome.new(log: fake_log).run do |home|
      main = home.create_wallet
      remote = home.create_wallet
      File.write(remote.path, File.read(main.path))
      remote.add(Zold::Txn.new(1, Time.now, Zold::Amount.new(zld: 11.0), 'NOPREFIX', Zold::Id.new, 'fake'))
      copies = home.copies(main)
      copies.add(File.read(remote.path), 'fake-host', 80, 0)
      Zold::Merge.new(wallets: home.wallets, remotes: home.remotes, copies: copies.root, log: fake_log).run(
        ['merge', main.id.to_s, '--no-baseline']
      )
      assert_equal(Zold::Amount::ZERO, main.balance)
    end
  end

  base = 'fixtures/merge'
  Dir.new(base).select { |f| File.directory?(File.join(base, f)) && !f.start_with?('.') }.each do |f|
    method = "test_#{f}"
    define_method(method) do
      Dir.mktmpdir do |dir|
        FileUtils.cp_r(File.join('fixtures/merge', "#{f}/."), dir)
        scores = File.join(dir, "copies/0123456789abcdef/scores#{Zold::Copies::EXT}")
        File.write(scores, File.read(scores).gsub('NOW', Time.now.utc.iso8601))
        FileUtils.cp('fixtures/merge/asserts.rb', dir)
        wallets = Zold::Wallets.new(dir)
        copies = File.join(dir, 'copies')
        remotes = Zold::Remotes.new(file: File.join(dir, 'remotes'))
        Zold::Merge.new(wallets: wallets, remotes: remotes, copies: copies, log: fake_log).run(
          %w[merge 0123456789abcdef] + File.read(File.join(dir, 'opts')).split("\n")
        )
        Dir.chdir(dir) do
          require File.join(dir, 'assert.rb')
        end
      end
    end
  end
end
