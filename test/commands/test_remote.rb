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
require 'zold/score'
require_relative '../test__helper'
require_relative '../../lib/zold/version'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/remotes'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/commands/remote'

# REMOTE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemote < Zold::Test
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
      stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
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
      stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: '{"version": "9.9.9"}'
      )
      log = TestLogger.new
      cmd = Zold::Remote.new(remotes: remotes, log: log)
      cmd.run(%w[remote clean])
      cmd.run(['remote', 'add', zero.host, zero.port.to_s, '--skip-ping'])
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping', '--reboot'])
      assert(log.msgs.to_s.include?(', reboot!'))
      log.msgs = []
      stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: "{\"version\": \"#{Zold::VERSION}\"}"
      )
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping', '--reboot'])
      assert(!log.msgs.to_s.include?(', reboot!'))
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

  def test_resets_remotes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      Zold::Remote.new(remotes: remotes, log: test_log).run(%w[remote reset])
    end
  end

  def test_remote_trim_with_tolerate
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      score = Zold::Score.new(
        host: 'aa1.example.org', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff'
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
      stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
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

  def test_select_selects_the_strongest_nodes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      suffixes = []
      (5000..5010).each do |port|
        score = Zold::Score.new(
          host: 'example.com',
          port: port,
          invoice: 'MYPREFIX@ffffffffffffffff',
          suffixes: suffixes << '13f7f01'
        )
        stub_request(:get, "http://#{score.host}:#{score.port}/remotes").to_return(
          status: 200,
          body: {
            version: Zold::VERSION,
            score: score.to_h,
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
        remotes.rescore('localhost', port, score)
      end
      cmd.run(%w[remote select --max-nodes=5])
      assert_equal(5, remotes.all.count)
      scores = remotes.all.map { |r| r[:score] }
      assert_equal([11, 10, 9, 8, 7], scores)
    end
  end

  def test_select_respects_max_nodes_option
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      remotes.defaults
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
      assert_equal(11 + File.readlines('resources/remotes').count, remotes.all.count)
      cmd.run(%w[remote select --max-nodes=5])
      assert_equal(5, remotes.all.count)
    end
  end

  def test_sets_defaults
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      cmd = Zold::Remote.new(remotes: remotes, log: test_log)
      cmd.run(%w[remote defaults])
      assert(!remotes.all.empty?)
    end
  end

  def test_remotes_baner
    log = TestLogger.new
    Zold::Remote.new(remotes: '',  log: log).run(['remote', '--help'])
    assert(log.msgs.include?("Usage: zold remote <command> [options]\nAvailable commands:\n    \e[32mremote show\e[0m\n      Show all registered remote nodes\n    \e[32mremote clean\e[0m\n      Remove all registered remote nodes\n    \e[32mremote reset\e[0m\n      Restore it back to the default list of nodes\n    \e[32mremote defaults\e[0m\n      Add all default nodes to the list\n    \e[32mremote add\e[0m host [port]\n      Add a new remote node\n      Available options:\n        --ignore-node  Ignore this node and never add it to the list\n        --skip-ping  Don't ping back the node when adding it (not recommended)\n        --network  The name of the network we work in (default: zold\n    \e[32mremote remove\e[0m host [port]\n      Remove the remote node\n    \e[32mremote elect\e[0m\n      Pick a random remote node as a target for a bonus awarding\n      Available options:\n        --ignore-score-weakness  Don't complain when their score is too weak\n        --ignore-score-value  Don't complain when their score is too small\n        --min-score  The minimum score required for winning the election (default: 8)\n        --max-winners  The maximum amount of election winners the election (default: 1)\n    \e[32mremote trim\e[0m\n      Remove the least reliable nodes\n      Available options:\n        --tolerate  Maximum level of errors we are able to tolerate\n    \e[32mremote select [options]\e[0m\n      Select the strongest n nodes.\n      Available options:\n        --max-nodes  Number of nodes to limit to. Defaults to 16.\n    \e[32mremote update\e[0m\n      Check each registered remote node for availability\n      Available options:\n        --ignore-score-weakness Don't complain when their score is too weak\n        --reboot  Exit if any node reports version higher than we have\n        --depth  The amount of update cycles to run, in order to fetch as many nodes as possible (default: 2)\n    --help  Print instructions\n"))
  end
end
