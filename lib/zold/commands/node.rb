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

require 'slop'
require_relative '../node/front.rb'
require_relative '../log.rb'
require_relative '../node/front'

# NODE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # NODE command
  class Node
    def initialize(log: Log::Quiet.new)
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true) do |o|
        o.banner = 'Usage: zold node [options]'
        o.integer '--port', 'TCP port to open for the Net (default: 80)',
          default: 80
        o.integer '--bind-port', 'TCP port to listen on (default: 80)',
          default: 80
        o.string '--host', 'Host name (default: 127.0.0.1)',
          default: '127.0.0.1'
        o.string '--home', 'Home directory (default: current directory)',
          default: Dir.pwd
        o.integer '--threads',
          'How many threads to use for scores finding (default: 8)',
          default: 8
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      Zold::Front.set(:port, opts['bind-port'])
      Zold::Front.set(:wallets, Wallets.new(opts[:home]))
      farm = Farm.new(log: @log)
      farm.start(opts[:host], opts[:port], threads: opts[:threads])
      Zold::Front.set(:farm, farm)
      Zold::Front.run!
    end
  end
end
