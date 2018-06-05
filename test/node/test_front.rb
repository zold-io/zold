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
require_relative '../test__helper'
require_relative 'fake_node'
require_relative '../../lib/zold/http'
require_relative '../../lib/zold/score'

class FrontTest < Minitest::Test
  def test_renders_public_pages
    FakeNode.new(log: $log).run(['--ignore-score-weakness']) do |port|
      {
        '200' => [
          '/robots.txt',
          '/',
          '/remotes'
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
      score = Zold::Score.new(
        Time.now, 'localhost', 999,
        'NOPREFIX@ffffffffffffffff',
        strength: 1
      ).next.next.next.next
      Zold::Http.new(URI("http://localhost:#{port}/"), score).get
      json = JSON.parse(Zold::Http.new(URI("http://localhost:#{port}/remotes"), score).get.body)
      assert(json['all'].find { |r| r['host'] == 'localhost' })
    end
  end

  def test_different_logos
    {
      '0' => 'https://www.zold.io/images/logo-red.png',
      '4' => 'https://www.zold.io/images/logo-orange.png',
      '16' => 'https://www.zold.io/images/logo-green.png'
    }.each do |num, path|
      $log.info("Calculating score #{num}...")
      score = Zold::Score.new(
        Time.now, 'localhost', 999,
        'NOPREFIX@ffffffffffffffff',
        strength: 1
      )
      num.to_i.times do
        score = score.next
      end
      $log.info("Score #{num} calculated.")
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
    FakeNode.new(log: $log).run(['--ignore-score-weakness']) do |port|
      response = Zold::Http.new(URI("http://localhost:#{port}/")).get
      assert_equal(
        '200', response.code,
        "Expected HTTP 200 OK: Found #{response.code}"
      )
      assert_operator(
        500, :>, response['content-length'].to_i,
        'Expected the content to be smaller than 500bytes for gzip'
      )
    end
  end
end
