# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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

class FarmTest < Zold::Test
  def test_renders_in_json
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX6@ffffffffffffffff', File.join(dir, 'f'), log: test_log, strength: 2)
      farm.start('localhost', 80, threads: 2) do
        assert_wait { !farm.best.empty? && !farm.best[0].value.zero? }
        count = 0
        100.times { count += farm.to_json[:best].length }
        assert(count.positive?)
      end
    end
  end

  def test_renders_in_text
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX7@ffffffffffffffff', File.join(dir, 'f'), log: test_log, strength: 1)
      farm.start('localhost', 80, threads: 2) do
        assert(!farm.to_text.nil?)
      end
    end
  end

  def test_makes_many_scores
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX6@ffffffffffffffff', File.join(dir, 'f'),
        log: test_log, lifetime: 10, farmer: Zold::Farmers::Plain.new, strength: 1)
      farm.start('localhost', 80, threads: 4) do
        assert_wait { farm.best.length == 4 }
      end
    end
  end

  # @todo #527:30min This test takes too long. The speed should be less than
  #  a few milliseconds, however, if you run it a few times, you will see
  #  that it is over 100ms sometimes. This is way too slow. I can't understand
  #  what's going on. It seems that IO.read() is taking too long sometimes.
  #  Try to measure its time of execution in Farm.load() and you will see
  #  that it's usually a few microseconds, but sometimes over 200ms.
  def test_reads_scores_at_high_speed
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX6@ffffffffffffffff', File.join(dir, 'f'), log: test_log, strength: 4)
      farm.start('localhost', 80, threads: 4) do
        assert_wait { !farm.best.empty? && !farm.best[0].value.zero? }
        cycles = 100
        speed = (0..cycles - 1).map do
          start = Time.now
          farm.best
          Time.now - start
        end.inject(&:+) / cycles
        test_log.info("Average speed is #{(speed * 1000).round(2)}ms in #{cycles} cycles")
      end
    end
  end

  def test_makes_best_score_in_background
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX1@ffffffffffffffff', File.join(dir, 'f'), log: test_log, strength: 3)
      farm.start('localhost', 80, threads: 1) do
        assert_wait { !farm.best.empty? && farm.best[0].value >= 3 }
        score = farm.best[0]
        assert(!score.expired?)
        assert(score.value >= 3)
      end
    end
  end

  def test_correct_score_from_empty_farm
    Dir.mktmpdir do |dir|
      farm = Zold::Farm.new('NOPREFIX2@cccccccccccccccc', File.join(dir, 'f'), log: test_log, strength: 1)
      farm.start('example.com', 8080, threads: 0) do
        score = farm.best[0]
        assert(!score.expired?)
        assert_equal(0, score.value)
        assert_equal('example.com', score.host)
        assert_equal(8080, score.port)
      end
    end
  end

  def test_pre_loads_history
    Dir.mktmpdir do |dir|
      cache = File.join(dir, 'a/b/c/cache')
      farm = Zold::Farm.new('NOPREFIX3@cccccccccccccccc', cache, log: test_log, strength: 1)
      farm.start('example.com', 8080, threads: 0) do
        score = farm.best[0]
        assert(!score.nil?, 'The list of best scores can\'t be empty!')
        assert(File.exist?(cache), 'The cache file has to be created!')
        assert_equal(0, score.value)
        assert(!score.expired?)
        assert_equal('example.com', score.host)
        assert_equal(8080, score.port)
      end
    end
  end

  def test_drops_expired_scores_from_history
    Dir.mktmpdir do |dir|
      cache = File.join(dir, 'cache')
      score = Zold::Score.new(
        time: Time.parse('2017-07-19T21:24:51Z'),
        host: 'some-host', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff',
        suffixes: %w[13f7f01 b2b32b 4ade7e],
        strength: 6
      )
      IO.write(cache, score.to_s)
      farm = Zold::Farm.new('NOPREFIX4@ffffffffffffffff', cache, log: test_log, strength: score.strength)
      farm.start(score.host, score.port, threads: 1) do
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
    log = TestLogger.new
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'corrupted_farm')
      [
        'some garbage',
        'some other garbage'
      ].each do |score_garbage_line|
        valid_score = Zold::Score.new(
          time: Time.parse('2017-07-19T21:24:51Z'),
          host: 'some-host', port: 9999, invoice: 'NOPREFIX5@ffffffffffffffff',
          suffixes: %w[13f7f01 b2b32b 4ade7e], strength: 6
        )
        File.open(file, 'w') do |f|
          f.puts(score_garbage_line)
          f.puts(valid_score)
        end
        farm = Zold::Farm.new('NOPREFIX5@ffffffffffffffff', file, log: log)
        assert_equal(1, farm.best.count)
        assert(log.msgs.find { |m| m.include?('Invalid score') }, log.msgs)
      end
    end
  end

  def test_terminates_farm_entirely
    Zold::Farm.new('NOPREFIX4@ffffffffffffffff', log: test_log, strength: 10).start('localhost', 4096, threads: 1) do
      sleep 1
    end
  end
end
