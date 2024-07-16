# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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
      FakeNode.new(log: fake_log).run(opts('--network=foo')) do |port|
        100.times do
          Zold::Http.new(uri: "http://localhost:#{port}/", network: 'foo').get
        end
      end
    end
    report.pretty_print
  end

  def test_renders_front_json
    FakeNode.new(log: fake_log).run(opts('--network=foo')) do |port|
      res = Zold::Http.new(uri: "http://localhost:#{port}/", network: 'foo').get
      json = JSON.parse(res.body)
      assert_equal(Zold::VERSION, json['version'])
      assert_equal(Zold::PROTOCOL, json['protocol'])
      assert_equal('foo', json['network'])
      assert_equal('zold-io/zold', json['repo'])
      assert(json['pid'].positive?, json)
      assert(json['cpus'].positive?, json)
      assert(!json['journal'].negative?, json)
      assert(json['memory'].positive?, json)
      assert(!json['load'].negative?, json)
      assert(json['wallets'].positive?, json)
      assert(json['remotes'].zero?, json)
      assert(json['nscore'].zero?, json)
    end
  end

  def test_renders_public_pages
    FakeNode.new(log: fake_log).run(opts) do |port|
      {
        200 => [
          '/robots.txt',
          '/',
          '/remotes',
          '/version',
          '/protocol',
          '/farm',
          '/ledger',
          '/ledger.json',
          '/metronome',
          '/journal',
          '/score',
          '/queue',
          '/trace',
          '/threads',
          '/ps'
        ],
        404 => [
          '/this-is-absent',
          '/wallet/ffffeeeeddddcccc',
          '/wallet/ffffeeeeddddcccc.bin',
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
            code, response.status,
            "Invalid response code for #{uri}: #{response.status_line}"
          )
        end
      end
    end
  end

  def test_updates_list_of_remotes
    FakeNode.new(log: fake_log).run(['--no-metronome', '--ignore-score-weakness', '--no-cache']) do |port|
      (Zold::Remotes::MAX_NODES + 5).times do |i|
        score = Zold::Score.new(
          host: 'localhost', port: i + 1, invoice: 'NOPREFIX@ffffffffffffffff', strength: 1
        ).next.next.next.next
        response = Zold::Http.new(uri: "http://localhost:#{port}/remotes", score: score).get
        assert_equal(200, response.status, response.body)
        assert_equal(
          [i + 1, Zold::Remotes::MAX_NODES + 1].min,
          Zold::JsonPage.new(response.body).to_hash['all'].count, response.body
        )
        assert_match(
          /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z/,
          Zold::JsonPage.new(response.body).to_hash['mtime'].to_s,
          response.body
        )
      end
    end
  end

  def test_increments_score
    FakeNode.new(log: fake_log).run(opts('--threads=1')) do |port|
      3.times do |i|
        assert_equal_wait(true, max: 60) do
          response = Zold::Http.new(uri: "http://localhost:#{port}/").get
          assert_equal(200, response.status, response.body)
          score = Zold::Score.parse_json(Zold::JsonPage.new(response.body).to_hash['score'])
          score.value >= i
        end
      end
    end
  end

  [
    '.txt', '.html',
    '/balance', '/key', '/mtime',
    '/digest', '/size',
    '/age', '/mnemo', '/debt', '/txns',
    '/txns.json', '.bin', '/copies'
  ].each do |p|
    method = "test_wallet_page_#{p.gsub(/[^a-z]/, '_')}"
    define_method(method) do
      FakeHome.new(log: fake_log).run do |home|
        FakeNode.new(log: fake_log).run(opts) do |port|
          wallet = home.create_wallet(txns: 2)
          base = "http://localhost:#{port}"
          response = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
          assert_equal(200, response.status, response.body)
          assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
          assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}#{p}").get.status }
        end
      end
    end
  end

  def test_renders_wallets_page
    FakeHome.new(log: fake_log).run do |home|
      FakeNode.new(log: fake_log).run(opts) do |port|
        wallet = home.create_wallet(txns: 2)
        base = "http://localhost:#{port}"
        response = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
        assert_equal(200, response.status, response.body)
        assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
        response = Zold::Http.new(uri: "#{base}/wallets").get
        assert_equal(200, response.status, response.body)
        assert(response.body.to_s.split("\n").include?(wallet.id.to_s), response.body)
      end
    end
  end

  def test_fetch_in_multiple_threads
    FakeNode.new(log: fake_log).run(opts) do |port|
      FakeHome.new(log: fake_log).run do |home|
        wallet = home.create_wallet
        base = "http://localhost:#{port}"
        Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
        assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
        threads = []
        mutex = Mutex.new
        Threads.new(6).assert(100) do
          assert_equal_wait(200) do
            res = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get
            mutex.synchronize { threads << res.headers['X-Zold-Thread'] }
            res.status
          end
        end
        assert(threads.uniq.count > 1)
      end
    end
  end

  def test_pushes_twice
    FakeNode.new(log: fake_log).run(opts) do |port|
      FakeHome.new(log: fake_log).run do |home|
        wallet = home.create_wallet
        base = "http://localhost:#{port}"
        assert_equal(
          200,
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path).status
        )
        assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
        3.times do
          r = Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
          assert_equal(304, r.status, r.body)
        end
      end
    end
  end

  def test_pushes_many_wallets
    FakeNode.new(log: fake_log).run(opts) do |port|
      base = "http://localhost:#{port}"
      FakeHome.new(log: fake_log).run do |home|
        Threads.new(5).assert do
          wallet = home.create_wallet
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
          assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
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
    FakeNode.new(log: fake_log).run(opts) do |port|
      response = Zold::Http.new(uri: URI("http://localhost:#{port}/version")).get
      assert_equal(200, response.status, response)
      assert_operator(300, :>, response.body.length.to_i, 'Expected the content to be small')
    end
  end

  def test_performance
    times = Queue.new
    FakeNode.new(log: fake_log).run(opts('--threads=4', '--strength=6')) do |port|
      Threads.new(10).assert(100) do
        start = Time.now
        Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
        times << (Time.now - start)
      end
    end
    all = []
    all << times.pop(true) until times.empty?
    fake_log.info("Average response time is #{all.inject(&:+) / all.count}")
  end

  # The score exposed via the HTTP header must be reduced to the value of 16.
  # We need this in order to optimize the amount of data we transfer in each
  # HTTP request. This value is enough to identify a valueable node, and filter
  # out those that are too weak.
  def test_score_is_reduced
    FakeNode.new(log: fake_log).run(opts('--threads=1', '--strength=1', '--farmer=plain')) do |port|
      scores = []
      50.times do
        res = Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
        scores << Zold::Score.parse(res.headers[Zold::Http::SCORE_HEADER]).value
        sleep(0.1)
      end
      assert(scores.uniq.sort.reverse[0] <= Zold::Front::MIN_SCORE)
    end
  end

  def test_headers_are_being_set_correctly
    FakeNode.new(log: fake_log).run(opts('--expose-version=9.9.9')) do |port|
      response = Zold::Http.new(uri: URI("http://localhost:#{port}/")).get
      assert_equal('no-cache', response.headers['Cache-Control'])
      assert_equal('close', response.headers['Connection'])
      assert_equal('9.9.9', response.headers['X-Zold-Version'])
      assert_equal(app.settings.protocol.to_s, response.headers[Zold::Http::PROTOCOL_HEADER])
      assert_equal('*', response.headers['Access-Control-Allow-Origin'])
      assert(response.headers['X-Zold-Milliseconds'])
      assert(!response.headers[Zold::Http::SCORE_HEADER].nil?)
    end
  end

  def test_alias_parameter
    name = SecureRandom.hex(4)
    FakeNode.new(log: fake_log).run(opts("--alias=#{name}")) do |port|
      uri = URI("http://localhost:#{port}/")
      response = Zold::Http.new(uri: uri).get
      assert_match(
        name,
        Zold::JsonPage.new(response.body).to_hash['alias'].to_s,
        response.body
      )
    end
  end

  def test_default_alias_parameter
    FakeNode.new(log: fake_log).run(opts) do |port|
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
    skip
    exception = assert_raises RuntimeError do
      FakeNode.new(log: fake_log).run(opts('--alias=invalid-alias')) do |port|
        uri = URI("http://localhost:#{port}/")
        Zold::Http.new(uri: uri).get
      end
    end
    assert(exception.message.include?('should be a 4 to 16 char long'), exception.message)
  end

  def test_push_fetch_in_multiple_threads
    key = Zold::Key.new(text: File.read('fixtures/id_rsa'))
    FakeNode.new(log: fake_log).run(opts) do |port|
      FakeHome.new(log: fake_log).run do |home|
        wallet = home.create_wallet(Zold::Id::ROOT)
        base = "http://localhost:#{port}"
        Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
        assert_equal_wait(200) { Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status }
        cycles = 50
        cycles.times do
          wallet.sub(Zold::Amount.new(zents: 10), "NOPREFIX@#{Zold::Id.new}", key)
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").put(wallet.path)
          assert_equal(200, Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}").get.status)
        end
        assert_equal_wait(-10 * cycles) do
          Zold::Http.new(uri: "#{base}/wallet/#{wallet.id}/balance").get.body.to_i
        end
      end
    end
  end

  def test_checksum_in_json
    FakeNode.new(log: fake_log).run(opts) do |port|
      uri = URI("http://localhost:#{port}/")
      response = Zold::Http.new(uri: uri).get
      assert(
        Zold::JsonPage.new(response.body).to_hash.key?('checksum'),
        response.body
      )
    end
  end

  private

  def opts(*extra)
    ['--no-metronome', '--ignore-score-weakness', '--standalone', '--threads=0', '--strength=1'] + extra
  end
end
