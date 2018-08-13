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
require 'tmpdir'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../lib/zold/version'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/score'
require_relative '../../lib/zold/commands/remote'

# REMOTE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemote < Minitest::Test
  def test_updates_remote
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'a/b/c/remotes'))
      zero = Zold::Score::ZERO
      stub_request(:get, "http://#{zero.host}:#{zero.port}/remotes").to_return(
        status: 200,
        body: {
          version: Zold::VERSION,
          score: zero.to_h,
          all: [
            { host: 'localhost', port: 888 },
            { host: 'localhost', port: 999 }
          ]
        }.to_json
      )
      stub_request(:get, 'http://localhost:2/remotes').to_return(
        status: 404
      )
      stub_request(:get, 'http://localhost:888/remotes').to_return(
        status: 404
      )
      stub_request(:get, 'http://localhost:999/remotes').to_return(
        status: 404
      )
      stub_request(:get, 'http://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: '{"version": "0.0.0"}'
      )
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      cmd.run(%w[remote clean])
      assert(remotes.all.empty?)
      cmd.run(['remote', 'add', zero.host, zero.port.to_s, '--skip-ping'])
      cmd.run(%w[remote add localhost 2 --skip-ping])
      assert_equal(2, remotes.all.count)
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping'])
      assert_equal(4, remotes.all.count)
    end
  end

  def test_new_version_rubygems
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      zero = Zold::Score::ZERO
      stub_request(:get, "http://#{zero.host}:#{zero.port}/remotes").to_return(
        status: 200,
        body: {
          version: Zold::VERSION,
          score: zero.to_h,
          all: [
            { host: zero.host, port: zero.port }
          ]
        }.to_json
      )
      stub_request(:get, 'http://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: '{"version": "9.9.9"}'
      )
      log = Minitest::Test::TestLogger.new
      cmd = Zold::Remote.new(remotes: remotes, log: log)
      cmd.run(%w[remote clean])
      cmd.run(['remote', 'add', zero.host, zero.port.to_s, '--skip-ping'])
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping', '--reboot'])
      assert(log.msg.to_s.include?(', reboot!'))
      log.msg = []
      stub_request(:get, 'http://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: "{\"version\": \"#{Zold::VERSION}\"}"
      )
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping', '--reboot'])
      assert(!log.msg.to_s.include?(', reboot!'))
    end
  end

  def test_elects_a_remote
    Dir.mktmpdir do |dir|
      zero = Zold::Score::ZERO
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      remotes.clean
      remotes.add(zero.host, zero.port)
      stub_request(:get, "http://#{zero.host}:#{zero.port}/").to_return(
        status: 200,
        body: {
          version: Zold::VERSION,
          score: zero.to_h
        }.to_json
      )
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      winners = cmd.run(%w[remote elect --ignore-score-value])
      assert_equal(1, winners.count)
    end
  end

  def test_remote_trim_with_tolerate
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      score = Zold::Score.new(
        time: Time.now, host: 'aa1.example.org', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff'
      )
      stub_request(:get, 'http://localhost:8883/version').to_return(
        status: 200,
        body: '0.0.0'
      )
      stub_request(:get, "http://#{score.host}:#{score.port}/remotes").to_return(
        status: 200,
        body: {
          version: Zold::VERSION,
          score: score.to_h,
          all: [
            { host: 'localhost', port: 8883 }
          ]
        }.to_json
      )
      stub_request(:get, 'http://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: '{"version": "0.0.0"}'
      )
      stub_request(:get, 'http://localhost:8883/remotes').to_return(status: 404)
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      cmd.run(%w[remote clean])
      assert(remotes.all.empty?)
      cmd.run(['remote', 'add', score.host, score.port.to_s, '--skip-ping'])
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping'])
      assert_equal(2, remotes.all.count)
      cmd.run(['remote', 'update', '--ignore-score-weakness'])
      cmd.run(['remote', 'trim', '--tolerate=0'])
      assert_equal(1, remotes.all.count)
    end
  end

  # @todo #329:30min Verify that the nodes that are being selected are
  #  really the strongest ones. The strongest nodes are the ones with
  #  the highest score.
  def test_select_selects_the_strongest_nodes
    skip
  end

  def test_select_respects_max_nodes_option
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      zero = Zold::Score::ZERO
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      (5000..5010).each do |port|
        stub_request(:get, "http://#{zero.host}:#{zero.port}/remotes").to_return(
          status: 200,
          body: {
            version: Zold::VERSION,
            score: zero.to_h,
            all: [
              { host: 'localhost', port: port }
            ]
          }.to_json
        )
        stub_request(:get, "http://localhost:#{port}/version").to_return(
          status: 200,
          body: {
            version: Zold::VERSION
          }.to_json
        )
        cmd.run(%W[remote add localhost #{port}])
      end
      assert_equal(12, remotes.all.count)
      cmd.run(%w[remote select --max-nodes=5])
      assert_equal(5, remotes.all.count)
    end
  end
end
