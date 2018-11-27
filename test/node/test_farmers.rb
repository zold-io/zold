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
require 'time'
require 'zold/score'
require_relative '../test__helper'
require_relative '../../lib/zold/node/farmers'

class FarmersTest < Zold::Test
  def test_calculates_next_score
    before = Zold::Score.new(host: 'some-host', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 3)
    [Zold::Farmers::Plain, Zold::Farmers::Spawn, Zold::Farmers::Fork].each do |farmer_class|
      farmer = farmer_class.new(log: test_log)
      after = farmer.up(before)
      assert_equal(1, after.value)
      assert(!after.expired?)
      assert_equal('some-host', after.host)
      assert_equal(9999, after.port)
    end
  end

  def test_calculates_large_score
    log = TestLogger.new(test_log)
    thread = Thread.start do
      [Zold::Farmers::Spawn, Zold::Farmers::Fork].each do |farmer_class|
        farmer = farmer_class.new(log: log)
        farmer.up(Zold::Score.new(host: 'a', port: 1, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 20))
      end
    end
    assert_wait { !log.msgs.find { |m| m.include?('Scoring started') }.nil? }
    thread.kill
    thread.join
    assert(log.msgs.find { |m| m.include?('killed') })
  end

  def test_avoid_duplicate_processes
    log = TestLogger.new(test_log)
    time = Time.now
    thread = Thread.start do
      [Zold::Farmers::Spawn, Zold::Farmers::Fork].each do |farmer_class|
        farmer = farmer_class.new(log: log)
        farmer.up(Zold::Score.new(time: time, host: 'a', port: 1, invoice: 'prefixone@ffffffffffffffff', strength: 20))
      end
    end
    assert_wait { !log.msgs.find { |m| m.include?('Scoring started') }.nil? }
    assert_raises do
      [Zold::Farmers::Spawn, Zold::Farmers::Fork].each do |farmer_class|
        farmer_class.new(log: log).up(
          Zold::Score.new(time: time, host: 'a', port: 1, invoice: 'prefixtwo@ffffffffffffffff', strength: 20)
        )
      end
    end
    thread.kill
    thread.join
  end
end
