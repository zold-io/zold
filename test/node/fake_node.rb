# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require 'random-port'
require_relative '../fake_home'
require_relative '../../lib/zold/log'
require_relative '../../lib/zold/http'
require_relative '../../lib/zold/verbose_thread'
require_relative '../../lib/zold/node/front'

# Fake node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class FakeNode
  def initialize(log: Zold::Log::NULL)
    @log = log
  end

  # This is a pretty weird situation: we have to acquire a single port
  # number an reuse it for all tests. If we use different port numbers,
  # acquiring them for each instance of FakeNode, we get port collisions,
  # sometimes. Maybe this can be fixed sometimes.
  # rubocop:disable Style/ClassVars
  @@port = RandomPort::Pool::SINGLETON.acquire
  # rubocop:enable Style/ClassVars

  def run(args = ['--standalone', '--no-metronome'])
    WebMock.allow_net_connect!
    FakeHome.new(log: @log).run do |home|
      node = Thread.new do
        Thread.current.name = 'fake_node'
        Thread.current.abort_on_exception = false
        Zold::VerboseThread.new(@log).run do
          require_relative '../../lib/zold/commands/node'
          Zold::Node.new(wallets: home.wallets, remotes: home.remotes, copies: home.copies.root, log: @log).run(
            [
              '--home', home.dir,
              '--network=test',
              '--port', @@port.to_s,
              '--host=localhost',
              '--bind-port', @@port.to_s,
              '--threads=1',
              '--dump-errors',
              '--strength=2',
              '--halt-code=test',
              '--routine-immediately',
              '--invoice=NOPREFIX@ffffffffffffffff'
            ] + args
          )
        end
      end
      uri = "http://localhost:#{@@port}/"
      attempt = 0
      loop do
        ping = Zold::Http.new(uri: uri).get
        unless ping.status == 599 && node.alive?
          @log.debug("The URL #{uri} is probably alive, after #{attempt} attempts")
          break
        end
        unless node.alive?
          @log.debug("The URL #{uri} is dead, after #{attempt} attempts")
          break
        end
        @log.debug("Waiting for #{uri} (attempt no.#{attempt}): ##{ping.status}...")
        sleep 0.5
        attempt += 1
        if attempt > 10
          @log.error("Waiting for too long for #{uri} (#{attempt} attempts)")
          break
        end
      end
      raise "The node is dead at #{uri}" unless node.alive?
      begin
        yield @@port
      ensure
        Zold::Http.new(uri: "#{uri}?halt=test").get
        node.join
        sleep 0.1 # stupid sleep to make sure all threads are terminated
      end
      @log.debug("Thread with fake node stopped: #{node.alive?}")
    end
  end
end
