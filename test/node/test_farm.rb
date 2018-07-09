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
  class SaveLastMessageLogger
    attr_reader :msg
    def error(msg)
      @msg = msg
    end

    def debug(msg); end
  end

  def test_renders_in_json
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', File.join(dir, 'f'), log: test_log)
      farm.start('localhost', 80, threads: 4, strength: 2) do
        sleep 0.1 while farm.best.empty? || farm.best[0].value.zero?
        count = 0
        100.times { count += farm.to_json[:best].length }
        assert(count > 0)
      end
    end
  end

  def test_renders_in_text
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', File.join(dir, 'f'), log: test_log)
      farm.start('localhost', 80, threads: 2, strength: 1) do
        assert(!farm.to_text.nil?)
      end
    end
  end

  def test_makes_best_score_in_background
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', File.join(dir, 'f'), log: test_log)
      farm.start('localhost', 80, threads: 4, strength: 2) do
        sleep 0.1 while farm.best.empty? || farm.best[0].value.zero?
        score = farm.best[0]
        assert(!score.expired?)
        assert(score.value > 0)
      end
    end
  end

  def test_correct_score_from_empty_farm
    Dir.mktmpdir 'test' do |dir|
      farm = Zold::Farm.new('NOPREFIX@cccccccccccccccc', File.join(dir, 'f'), log: test_log)
      farm.start('example.com', 8080, threads: 0, strength: 1) do
        score = farm.best[0]
        assert(!score.expired?)
        assert_equal(0, score.value)
        assert_equal('example.com', score.host)
        assert_equal(8080, score.port)
      end
    end
  end

  def test_pre_loads_history
    Dir.mktmpdir 'test' do |dir|
      cache = File.join(dir, 'cache')
      farm = Zold::Farm.new('NOPREFIX@cccccccccccccccc', cache, log: test_log)
      farm.start('example.com', 8080, threads: 0, strength: 1) do
        score = farm.best[0]
        assert_equal(0, score.value)
        assert(!score.expired?)
        assert_equal('example.com', score.host)
        assert_equal(8080, score.port)
      end
    end
  end

  def test_drops_expired_scores_from_history
    Dir.mktmpdir 'test' do |dir|
      cache = File.join(dir, 'cache')
      score = Zold::Score.new(
        Time.parse('2017-07-19T21:24:51Z'),
        'some-host', 9999, 'NOPREFIX@ffffffffffffffff', %w[13f7f01 b2b32b 4ade7e],
        strength: 6
      )
      File.write(cache, score.to_s)
      farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', cache, log: test_log)
      farm.start(score.host, score.port, threads: 1, strength: score.strength) do
        100.times do
          sleep(0.1)
          b = farm.best[0]
          assert(!b.nil?)
          break if b.value.zero?
        end
        assert_equal(0, farm.best[0].value)
      end
    end
  end

  def test_garbage_farm_file
    log = SaveLastMessageLogger.new
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'corrupted_farm')
      [
        "0/6: 2018-06-26ABCT00:32:43Z 178.128.165.12 4096 MIRhypo1@c13620484b46caa4\n",
        "some garbage\n"
      ].each do |score_garbage_line|
        File.write(file, score_garbage_line)
        score = Zold::Score.new(
          Time.parse('2017-07-19T21:24:51Z'),
          'some-host', 9999, 'NOPREFIX@ffffffffffffffff', %w[13f7f01 b2b32b 4ade7e],
          strength: 6
        )
        File.write(file, score_garbage_line + score.to_s)
        farm = Zold::Farm.new('NOPREFIX@ffffffffffffffff', file, log: log)
        assert_equal(1, farm.best.count)
        assert(log.msg.start_with?('Invalid score'))
      end
    end
  end
end
