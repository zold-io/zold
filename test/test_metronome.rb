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
require_relative 'test__helper'
require_relative '../lib/zold/metronome'

# Metronome test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestMetronome < Minitest::Test
  def test_start_and_stop
    metronome = Zold::Metronome.new(test_log)
    list = []
    metronome.add(FakeRoutine.new(list))
    sleep 0.1 while list.empty?
    metronome.stop
    assert_equal(1, list.count)
  end

  def test_continues_even_after_error
    metronome = Zold::Metronome.new(test_log)
    routine = BrokenRoutine.new
    metronome.add(routine)
    sleep 0.1 while routine.count < 2
    metronome.stop
    assert(routine.count > 1)
  end

  class FakeRoutine
    def initialize(list)
      @list = list
    end

    def exec(i)
      @list << i
      sleep(6000)
    end
  end

  class BrokenRoutine
    attr_reader :count
    def exec(i)
      @count = i
      raise
    end
  end
end
