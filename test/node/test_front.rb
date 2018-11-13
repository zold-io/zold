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
require 'json'
require 'time'
require 'securerandom'
require 'threads'
require 'zold/score'
require 'memory_profiler'
require_relative '../test__helper'
require_relative 'fake_node'
require_relative '../fake_home'
require_relative '../../lib/zold/http'
require_relative '../../lib/zold/age'
require_relative '../../lib/zold/json_page'

class FrontTest < Zold::Test
  def app
    Zold::Front
  end

  # Use this test to check how much memory is being used after doing a large
  # number of routine operations. There should be no suspicious information
  # in the report, which will be printed to the console.
  def test_memory_leakage
    skip
    report = MemoryProfiler.report(top: 10) do
      FakeNode.new(log: test_log).run(['--no-metronome', '--network=foo', '--threads=0']) do |port|
        100.times do
          Zold::Http.new(uri: "http://localhost:#{port}/", network: 'foo').get
        end
      end
    end
    report.pretty_print
  end

  def test_renders_front_json
    FakeNode.new(log: test_log).run(['--no-metronome', '--network=foo', '--threads=0']) do |port|
      res = Zold::Http.new(uri: "http://localhost:#{port}/", network: 'foo').get
      json = JSON.parse(res.body)
      assert_equal(Zold::VERSION, json['version'])
      assert_equal(Zold::PROTOCOL, json['protocol'])
      assert_equal('foo', json['network'])
      assert(json['pid'].positive?)
      assert(json['cpus'].positive?)
      assert(json['memory'].positive?)
      assert(json['load'].positive?)
      assert(json['wallets'].positive?)
      assert(json['remotes'].zero?)
      assert(json['nscore'].zero?)
    end
  end

  def test_renders_public_pages
    FakeNode.new(log: test_log).run(['--ignore-score-weakness', '--no-metronome', '--threads=0']) do |port|
      {
        '200' => [
          '/robots.txt',
          '/',
          '/remotes',
          '/version',
          '/protocol',
          '/farm',
          '/metronome',
          '/score',
          '/trace',
          '/threads',
          '/ps'
        ],
        '404' => [
          '/this-is-absent',
          '/wallet/ffffeeeeddddcccc',
          '/wallet/ffffeeeeddddcccc.bin',
          '/wallet/ffffeeeeddddcccc.json',
          '/wallet/ffffeeeeddddcccc.txt',
          '/wallet/ffffeeeeddddcccc/balance',
          '/wallet/ffffeeeeddddcccc/key',
          '/wallet/ffffeeeeddddcccc/mtime',
          '/wallet/ffffeeeeddddcccc/digest'
        ]
      }.each do |code, paths|
        paths.each do |p|
          uri = URI("http://localhost:#{port}#{p}")
          response = Zold::Http.new(uri: uri).get
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
        host: 'localhost', port: port, invoice: 'NOPREFIX@ffffffffffffffff', strength: 1
      ).next.next.next.next
      response = Zold::Http.new(uri: "http://localhost:#{port}/remotes", score: score).get
      assert_equal('200', response.code, response.body)
      assert_equal(1, Zold::JsonPage.new(response.body).to_hash['all'].count, response.body)
      assert_match(
        /(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})Z/,
        Zold::JsonPage.new(response.body).to_hash['mtime'].to_s,
        response.body
      )
    end
  end

  def test_increments_score
    FakeNode.new(log: test_log).run(['--threads=1', '--strength=1', '--no-metronome']) do |port|
      3.times do |i|
        assert_equal_wait(true) do
          response = Zold::Http.new(uri: "http://localhost:#{port}/").get
          assert_equal('200', response.code, response.body)
          score = Zold::Score.parse_json(Zold::JsonPage.new(response.body).to_hash['score'])
          score.value >= i
        end
      end
    end
  end

  def test_renders_wallet_pages
    FakeHome.new(log: test_log).run do |home|
      FakeNode.new(log: test_log).run(['--ignore-score-weakness', '--standalone']) do |port|
        wallet = home.create_wallet
        base = "http://localhost:#{port}"
        response = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}")
          .put(IO.read(wallet.path))
        assert_equal('200', response.code, response.body)
        assert_equal_wait('200') { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code }
        [
          "/wallet/#{wallet.id}.txt",
          "/wallet/#{wallet.id}.json",
          "/wallet/#{wallet.id}/balance",
          "/wallet/#{wallet.id}/key",
          "/wallet/#{wallet.id}/mtime",
          "/wallet/#{wallet.id}/digest",
          "/wallet/#{wallet.id}/size",
          "/wallet/#{wallet.id}/age",
          "/wallet/#{wallet.id}/mnemo",
          "/wallet/#{wallet.id}.bin",
          "/wallet/#{wallet.id}/copies"
        ].each do |u|
          assert_equal_wait('200') { Zold::Http.new(uri: "#{base}#{u}").get.code }
        end
      end
    end
  end

  def test_fetch_in_multiple_threads
    FakeNode.new(log: test_log).run(['--no-metronome', '--threads=0', '--standalone']) do |port|
      FakeHome.new(log: test_log).run do |home|
        wallet = home.create_wallet
        base = "http://localhost:#{port}"
        Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(IO.read(wallet.path))
        assert_equal_wait('200') { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code }
        threads = []
        mutex = Mutex.new
        Threads.new(6).assert(100) do
          assert_equal_wait('200') do
            res = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get
            mutex.synchronize { threads << res.header['X-Zold-Thread'] }
            res.code
          end
        end
        assert(threads.uniq.count > 1)
      end
    end
  end

  def test_pushes_twice
    FakeNode.new(log: test_log).run(['--no-metronome', '--threads=0', '--standalone']) do |port|
      FakeHome.new(log: test_log).run do |home|
        wallet = home.create_wallet
        base = "http://localhost:#{port}"
        assert_equal(
          '200',
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(IO.read(wallet.path)).code
        )
        assert_equal_wait('200') { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code }
        3.times do
          r = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}")
            .put(IO.read(wallet.path))
          assert_equal('304', r.code, r.body)
        end
      end
    end
  end

  def test_pushes_many_wallets
    FakeNode.new(log: test_log).run(['--no-metronome', '--threads=0', '--standalone']) do |port|
      base = "http://localhost:#{port}"
      FakeHome.new(log: test_log).run do |home|
        Threads.new(5).assert do
          wallet = home.create_wallet
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(IO.read(wallet.path))
          assert_equal_wait('200') { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code }
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
      score = Zold::Score.new(
        host: 'localhost', port: 999,
        invoice: 'NOPREFIX@ffffffffffffffff',
        strength: 1
      )
      num.to_i.times do
        score = score.next
      end
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
      response = Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
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

  def test_performance
    times = Queue.new
    FakeNode.new(log: test_log).run(['--threads=4', '--strength=6', '--no-metronome', '--farmer=ruby-proc']) do |port|
      Threads.new(10).assert(100) do
        start = Time.now
        Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
        times << Time.now - start
      end
    end
    all = []
    all << times.pop(true) until times.empty?
    test_log.info("Average response time is #{all.inject(&:+) / all.count}")
  end

  def test_headers_are_being_set_correctly
    Time.stub :now, Time.at(0) do
      FakeNode.new(log: test_log).run(['--expose-version=9.9.9', '--no-metronome', '--threads=0']) do |port|
        response = Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
        assert_equal('no-cache', response.header['Cache-Control'])
        assert_equal('close', response.header['Connection'])
        assert_equal('9.9.9', response.header['X-Zold-Version'])
        assert_equal(app.settings.protocol.to_s, response.header[Zold::Http::PROTOCOL_HEADER])
        assert_equal('*', response.header['Access-Control-Allow-Origin'])
        assert(response.header['X-Zold-Milliseconds'])
        assert(!response.header[Zold::Http::SCORE_HEADER].nil?)
      end
    end
  end

  def test_alias_parameter
    name = SecureRandom.hex(4)
    FakeNode.new(log: test_log).run(['--ignore-score-weakness', "--alias=#{name}"]) do |port|
      [
        '/',
        '/remotes'
      ].each do |path|
        uri = URI("http://localhost:#{port}#{path}")
        response = Zold::Http.new(uri: uri).get
        assert_match(
          name,
          Zold::JsonPage.new(response.body).to_hash['alias'].to_s,
          response.body
        )
      end
    end
  end

  def test_default_alias_parameter
    FakeNode.new(log: test_log).run(['--ignore-score-weakness', '--no-metronome']) do |port|
      uri = URI("http://localhost:#{port}/")
      response = Zold::Http.new(uri: uri).get
      assert_match(
        "localhost:#{port}",
        Zold::JsonPage.new(response.body).to_hash['alias'].to_s,
        response.body
      )
    end
  end

  def test_invalid_alias
    exception = assert_raises RuntimeError do
      FakeNode.new(log: test_log).run(['--ignore-score-weakness', '--alias=invalid-alias']) do |port|
        uri = URI("http://localhost:#{port}/")
        Zold::Http.new(uri: uri).get
      end
    end
    assert(exception.message.include?('should be a 4 to 16 char long'), exception.message)
  end

  def test_push_fetch_in_multiple_threads
    key = Zold::Key.new(text: IO.read('fixtures/id_rsa'))
    FakeNode.new(log: test_log).run(['--no-metronome', '--threads=0', '--standalone']) do |port|
      FakeHome.new(log: test_log).run do |home|
        wallet = home.create_wallet(Zold::Id::ROOT)
        base = "http://localhost:#{port}"
        Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(IO.read(wallet.path))
        assert_equal_wait('200') { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code }
        cycles = 50
        cycles.times do
          wallet.sub(Zold::Amount.new(zents: 10), "NOPREFIX@#{Zold::Id.new}", key)
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(IO.read(wallet.path))
          assert_equal('200', Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.code)
        end
        assert_equal_wait(-10 * cycles) do
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}/balance").get.body.to_i
        end
      end
    end
  end
end
