# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

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
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestRemote < Zold::Test
  def test_updates_remote
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'a/b/c/remotes'))
      zero = Zold::Score::ZERO
      stub_request(:get, "http://#{zero.host}:#{zero.port}/remotes").to_return(
        status: 200,
        headers: {},
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
        headers: {},
        body: '{"version": "0.0.0"}'
      )
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      cmd.run(%w[remote clean])
      assert(remotes.all.empty?)
      cmd.run(['remote', 'add', zero.host, zero.port.to_s, '--skip-ping'])
      cmd.run(%w[remote add localhost 2 --skip-ping])
      assert_equal(2, remotes.all.count)
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping'])
      assert_equal(4, remotes.all.count, remotes.all)
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
          repo: Zold::REPO,
          all: [
            { host: zero.host, port: zero.port }
          ]
        }.to_json
      )
      stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
        status: 200,
        body: "{\"version\": \"9.9.9\", \"repo\": \"#{Zold::REPO}\"}"
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
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      winners = cmd.run(%w[remote elect --ignore-score-value])
      assert_equal(1, winners.count)
    end
  end

  def test_resets_remotes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      Zold::Remote.new(remotes: remotes, log: fake_log).run(%w[remote reset])
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
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      cmd.run(%w[remote clean])
      assert(remotes.all.empty?)
      cmd.run(['remote', 'add', score.host, score.port.to_s, '--skip-ping'])
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--skip-ping'])
      assert_equal(2, remotes.all.count)
      cmd.run(['remote', 'update', '--ignore-score-weakness'])
      cmd.run(['remote', 'trim', '--tolerate=0'])
      assert_equal(1, remotes.all.count, remotes.all)
    end
  end

  def test_select_selects_the_strongest_nodes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      (1..11).each do |i|
        cmd.run(%W[remote add localhost #{i} --skip-ping])
        remotes.rescore('localhost', i, i)
        i.times { remotes.error('localhost', i) }
      end
      cmd.run(%w[remote select --max-nodes=5])
      assert_equal(5, remotes.all.count)
      scores = remotes.all.map { |r| r[:score] }
      assert_equal([7, 8, 9, 10, 11], scores.sort)
    end
  end

  def test_select_respects_max_nodes_option
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      remotes.masters
      zero = Zold::Score::ZERO
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
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
      assert_equal(11 + File.readlines('resources/masters').count, remotes.all.count)
      cmd.run(%w[remote select --max-nodes=5 --masters-too])
      assert_equal(5, remotes.all.count)
    end
  end

  def test_sets_masters
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      cmd.run(%w[remote masters])
      assert(!remotes.all.empty?)
    end
  end

  def test_select_doesnt_touch_masters
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.txt'))
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      cmd.run(%w[remote masters])
      cmd.run(%w[remote select --max-nodes=0])
      assert(!remotes.all.empty?)
    end
  end

  def test_updates_just_once
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'a/b/c/remotes'))
      zero = Zold::Score::ZERO
      get = stub_request(:get, "http://#{zero.host}:#{zero.port}/remotes").to_return(
        status: 200,
        headers: {},
        body: {
          version: Zold::VERSION,
          score: zero.to_h,
          all: []
        }.to_json
      )
      cmd = Zold::Remote.new(remotes: remotes, log: fake_log)
      cmd.run(['remote', 'add', zero.host, zero.port.to_s, '--skip-ping'])
      cmd.run(['remote', 'update', '--ignore-score-weakness', '--depth=10'])
      assert_equal(1, remotes.all.count)
      assert_requested(get, times: 1)
    end
  end
end
