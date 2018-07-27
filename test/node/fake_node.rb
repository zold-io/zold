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

require 'tmpdir'
require 'webmock/minitest'
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
  # rubocop:disable Style/ClassVars
  @@ports = Set.new
  # rubocop:enable Style/ClassVars

  def initialize(log: Zold::Log::Quiet.new)
    @log = log
  end

  def run(args = ['--standalone'])
    WebMock.allow_net_connect!
    start = Dir.pwd
    begin
      FakeHome.new.run do |home|
        port = FakeNode.random_port
        node = Thread.new do
          Zold::VerboseThread.new(@log).run do
            Thread.current.abort_on_exception = true
            Dir.chdir(home.dir)
            require_relative '../../lib/zold/commands/node'
            Zold::Node.new(wallets: home.wallets, remotes: home.remotes, copies: home.copies.root, log: @log).run(
              [
                '--network=test',
                '--port', port.to_s,
                '--host=localhost',
                '--bind-port', port.to_s,
                '--threads=1',
                '--dump-errors',
                '--strength=2',
                '--routine-immediately',
                '--invoice=NOPREFIX@ffffffffffffffff'
              ] + args
            )
          end
        end
        uri = "http://localhost:#{port}/"
        while Zold::Http.new(uri: uri, score: nil).get.code == '599' && node.alive?
          @log.debug("Waiting for #{uri}...")
          sleep 1
        end
        raise 'The node is dead' unless node.alive?
        begin
          yield port
        ensure
          Zold::Front.stop!
          node.join
        end
      end
    ensure
      Dir.chdir(start)
    end
  end

  def self.random_port
    loop do
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      next if @@ports.include?(port)
      @@ports << port
      return port
    end
  end
end
