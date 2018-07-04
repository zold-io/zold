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
    FakeHome.new.run do
      Zold::AsyncEntrance.new(FakeEntrance.new, log: test_log).start do |e|
        assert_equal(true, e.to_json[:'pool.running'])
      end
    end
  end

  def test_sends_through
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      basic = CountingEntrance.new
      Zold::AsyncEntrance.new(basic, log: test_log).start do |e|
        5.times { e.push(wallet.id, File.read(wallet.path)) }
        sleep 0.1 until e.to_json[:'pool.completed_task_count'] == 5
        assert_equal(5, basic.count)
        assert_equal(0, e.to_json[:'pool.queue_length'])
        assert_equal(5, e.to_json[:'pool.length'])
        assert_equal(5, e.to_json[:'pool.largest_length'])
      end
    end
  end

  def test_handles_broken_entrance_gracefully
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      Zold::AsyncEntrance.new(BrokenEntrance.new, log: test_log).start do |e|
        e.push(wallet.id, File.read(wallet.path))
        sleep 0.1 while e.to_json[:'pool.length'].zero?
        assert_equal(0, e.to_json[:'pool.queue_length'])
        assert_equal(1, e.to_json[:'pool.length'])
        assert_equal(1, e.to_json[:'pool.largest_length'])
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
