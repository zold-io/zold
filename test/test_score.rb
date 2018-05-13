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
require 'time'
require_relative '../lib/zold/score'

# Score test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestScore < Minitest::Test
  def test_validates_score
    score = Zold::Score.new(
      Time.parse('2017-07-19T21:24:51Z'),
      'localhost', 443,
      %w[9a81d5 40296e], strength: 6
    )
    assert(score.valid?)
    assert_equal(score.value, 2)
  end

  def test_reduces_itself
    score = Zold::Score.new(
      Time.parse('2017-07-19T21:24:51Z'),
      'localhost', 443, %w[A B C D E F G]
    ).reduced(2)
    assert_equal(score.value, 2)
  end

  def test_validates_wrong_score
    score = Zold::Score.new(
      Time.parse('2017-07-19T21:24:51Z'),
      'localhost', 443, %w[xxx yyy zzz]
    )
    assert_equal(score.value, 3)
    assert(!score.valid?)
  end

  def test_prints_and_parses
    time = Time.now
    score = Zold::Score.parse(
      Zold::Score.new(
        time, 'localhost', 999, %w[FIRST SECOND THIRD]
      ).to_s
    )
    assert_equal(score.value, 3)
    assert_equal(score.time.to_s, time.to_s)
    assert_equal(score.host, 'localhost')
    assert_equal(score.port, 999)
  end

  def test_finds_next_score
    score = Zold::Score.new(
      Time.parse('2017-07-19T21:24:51Z'), 'localhost', 443, strength: 4
    ).next
    assert_equal(score.value, 1)
    assert_equal(score.to_s, '1: 2017-07-19T21:24:51Z localhost 443 1169e')
    assert(score.valid?)
  end
end
