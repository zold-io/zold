# frozen_string_literal: true

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
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/async_entrance'
require_relative 'fake_entrance'

# AsyncEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestAsyncEntrance < Minitest::Test
  def test_renders_json
    FakeHome.new.run do |home|
      Zold::AsyncEntrance.new(FakeEntrance.new, home.dir, log: test_log).start do |e|
        assert_equal(true, e.to_json[:'pool.running'])
      end
    end
  end

  def test_sends_through_once
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      basic = CountingEntrance.new
      Zold::AsyncEntrance.new(basic, File.join(home.dir, 'a/b/c'), log: test_log).start do |e|
        e.push(wallet.id, File.read(wallet.path))
        assert_equal_wait(1) { basic.count }
      end
    end
  end

  def test_sends_through
    FakeHome.new.run do |home|
      basic = CountingEntrance.new
      Zold::AsyncEntrance.new(basic, File.join(home.dir, 'a/b/c'), log: test_log).start do |e|
        assert_in_threads(threads: 20) do
          wallet = home.create_wallet
          amount = Zold::Amount.new(zld: 39.99)
          key = Zold::Key.new(file: 'fixtures/id_rsa')
          wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
          5.times { e.push(wallet.id, File.read(wallet.path)) }
        end
      end
      assert_equal_wait(true) { basic.count >= 20 }
    end
  end

  def test_handles_broken_entrance_gracefully
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      Zold::AsyncEntrance.new(BrokenEntrance.new, home.dir, log: test_log).start do |e|
        e.push(wallet.id, File.read(wallet.path))
      end
    end
  end

  class CountingEntrance < FakeEntrance
    attr_reader :count
    def initialize
      @count = 0
    end

    def push(_, _)
      @count += 1
    end
  end

  class BrokenEntrance < FakeEntrance
    def push(_, _)
      raise 'It intentionally crashes'
    end
  end
end
