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
require 'json'
require 'time'
require_relative '../test__helper'
require_relative 'fake_node'
require_relative '../fake_home'
require_relative '../../lib/zold/http'
require_relative '../../lib/zold/json_page'
require_relative '../../lib/zold/score'

class FrontTest < Minitest::Test
  def test_renders_public_pages
    FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
      {
        '200' => [
          '/robots.txt',
          '/',
          '/remotes',
          '/version',
          '/farm',
          '/metronome',
          '/score'
        ],
        '404' => [
          '/this-is-absent',
          '/wallet/ffffeeeeddddcccc'
        ]
      }.each do |code, paths|
        paths.each do |p|
          uri = URI("http://localhost:#{port}#{p}")
          response = Zold::Http.new(uri).get
          assert_equal(
            code, response.code,
            "Invalid response code for #{uri}: #{response.message}"
          )
        end
      end
    end
  end

  def test_updates_list_of_remotes
    FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
      score = Zold::Score.new(
        Time.now, 'localhost', port, 'NOPREFIX@ffffffffffffffff', strength: 1
      ).next.next.next.next
      response = Zold::Http.new("http://localhost:#{port}/remotes", score).get
      assert_equal('200', response.code, response.body)
      assert_equal(1, Zold::JsonPage.new(response.body).to_hash['all'].count, response.body)
    end
  end

  # @todo #212:30min The test is skipped because it crashes
  #  sporadically. I don't know why. Let's investigate, find the
  #  cause and fix it properly: http://www.rultor.com/t/14887-396655530
  def test_renders_wallet_pages
    skip
    FakeHome.new.run do |home|
      FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
        wallet = home.create_wallet
        test_log.debug("Wallet created: #{wallet.id}")
        response = Zold::Http.new("http://localhost:#{port}/wallet/#{wallet.id}?sync=true").put(File.read(wallet.path))
        assert_equal('200', response.code, response.body)
        [
          "/wallet/#{wallet.id}",
          "/wallet/#{wallet.id}.txt",
          "/wallet/#{wallet.id}/balance",
          "/wallet/#{wallet.id}/key",
          "/wallet/#{wallet.id}/mtime"
        ].each do |u|
          res = Zold::Http.new(u).get
          assert_equal('200', res.code, res.body)
        end
      end
    end
  end

  # @todo #239:30min This tests is skipped since it crashes sporadically.
  #  Let's investigate and make it stable. I don't really know what's going
  #  on, but suspect some collision between threads:
  #  http://www.rultor.com/t/14940-397702802
  def test_pushes_twice
    skip
    FakeNode.new(log: test_log).run do |port|
      FakeHome.new.run do |home|
        wallet = home.create_wallet
        response = Zold::Http.new("http://localhost:#{port}/wallet/#{wallet.id}?sync=true").put(File.read(wallet.path))
        assert_equal('200', response.code, response.body)
        3.times do
          r = Zold::Http.new("http://localhost:#{port}/wallet/#{wallet.id}?sync=true").put(File.read(wallet.path))
          assert_equal('304', r.code, r.body)
        end
      end
    end
  end

  def test_different_logos
    {
      '0' => 'https://www.zold.io/images/logo-red.png',
      '4' => 'https://www.zold.io/images/logo-orange.png',
      '16' => 'https://www.zold.io/images/logo-green.png'
    }.each do |num, path|
      test_log.info("Calculating score #{num}...")
      score = Zold::Score.new(
        Time.now, 'localhost', 999,
        'NOPREFIX@ffffffffffffffff',
        strength: 1
      )
      num.to_i.times do
        score = score.next
      end
      test_log.info("Score #{num} calculated.")
      if score.value >= 16
        assert_equal(
          path, 'https://www.zold.io/images/logo-green.png',
          "Expected #{path} for score #{score.value}"
        )
      elsif score.value >= 4
        assert_equal(
          path, 'https://www.zold.io/images/logo-orange.png',
          "Expected #{path} for score #{score.value}"
        )
      else
        assert_equal(
          path, 'https://www.zold.io/images/logo-red.png',
          "Expected #{path} for score #{score.value}"
        )
      end
    end
  end

  def test_gzip
    FakeNode.new(log: test_log).run(['--ignore-score-weakness']) do |port|
      response = Zold::Http.new(URI("http://localhost:#{port}/")).get
      assert_equal(
        '200', response.code,
        "Expected HTTP 200 OK: Found #{response.code}"
      )
      assert_operator(
        750, :>, response['content-length'].to_i,
        'Expected the content to be smaller than 600 bytes for gzip'
      )
    end
  end
end
