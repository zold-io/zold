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
require_relative '../../lib/zold/log.rb'
require_relative '../../lib/zold/http.rb'
require_relative '../../lib/zold/commands/node.rb'

# Fake node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class FakeNode
  def initialize(log: Zold::Log::Quiet.new)
    @log = log
  end

  def run
    WebMock.allow_net_connect!
    Dir.mktmpdir 'test' do |dir|
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      node = Thread.new do
        begin
          Thread.current.abort_on_exception = true
          home = File.join(dir, 'node-home')
          Zold::Node.new(log: @log).run(
            [
              '--port', port.to_s,
              '--host=locahost',
              '--bind-port', port.to_s,
              '--threads=1',
              '--home', home
            ]
          )
        rescue StandardError => e
          @log.error(e.message + "\n" + e.backtrace.join("\n"))
        end
      end
      home = URI("http://localhost:#{port}/score.txt")
      while Zold::Http.new(home).get.code != '200' && node.alive?
        sleep 1
        @log.info("Waiting for #{home}...")
      end
      begin
        yield port
      rescue StandardError => e
        @log.error(e.message + "\n" + e.backtrace.join("\n"))
      ensure
        node.exit
      end
    end
  end
end
