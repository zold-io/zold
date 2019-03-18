# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class FakeNode
  def initialize(log: Zold::Log::NULL)
    @log = log
  end

  def run(args = ['--standalone', '--no-metronome'])
    WebMock.allow_net_connect!
    FakeHome.new(log: @log).run do |home|
      RandomPort::Pool::SINGLETON.acquire do |port|
        node = Thread.new do
          Thread.current.name = 'fake_node'
          Thread.current.abort_on_exception = true
          Zold::VerboseThread.new(@log).run do
            require_relative '../../lib/zold/commands/node'
            Zold::Node.new(wallets: home.wallets, remotes: home.remotes, copies: home.copies.root, log: @log).run(
              [
                '--home', home.dir,
                '--network=test',
                '--port', port.to_s,
                '--host=localhost',
                '--bind-port', port.to_s,
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
        uri = "http://localhost:#{port}/"
        attempt = 0
        loop do
          ping = Zold::Http.new(uri: uri).get
          break unless ping.status == 599 && node.alive?
          @log.info("Waiting for #{uri} (attempt no.#{attempt}): ##{ping.status}...")
          sleep 0.5
          attempt += 1
          break if attempt > 10
        end
        raise "The node is dead at #{uri}" unless node.alive?
        begin
          yield port
        ensure
          Zold::Http.new(uri: uri + '?halt=test').get
          node.join
          sleep 0.1 # stupid sleep to make sure all threads are terminated
        end
      end
    end
  end
end
