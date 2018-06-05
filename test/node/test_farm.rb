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
require 'rack/test'
require 'tmpdir'
require_relative '../test__helper'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/node/farm'

class FarmTest < Minitest::Test
  def test_makes_best_score_in_background
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', File.join(dir, 'f'), log: log)
      farm.start('localhost', 80, threads: 4, strength: 2)
      sleep 0.1 while farm.best.empty? || farm.best[0].value.zero?
      assert(farm.best[0].value > 0)
      farm.stop
    end
  end

  def test_correct_score_from_empty_farm
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@cccccccccccccccc', File.join(dir, 'f'), log: log)
      farm.start('example.com', 8080, threads: 0, strength: 1)
      score = farm.best[0]
      assert_equal(0, score.value)
      assert_equal('example.com', score.host)
      assert_equal(8080, score.port)
      farm.stop
    end
  end
end
