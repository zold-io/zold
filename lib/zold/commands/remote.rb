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

require 'rainbow'
require_relative '../log.rb'
require_relative '../remotes.rb'

# REMOTE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Remote command
  class Remote
    def initialize(wallets:, log: Log::Quiet.new)
      @remotes = Remotes.new(File.join(wallets.to_s, 'remotes'))
      @log = log
    end

    def run(args)
      command = args[0]
      case command
      when 'show'
        @remotes.all.each do |r|
          score = Rainbow("/#{r[:score]}").color(r[:score] > 0 ? :green : :red)
          @log.info(r[:address] + Rainbow(":#{r[:port]}").gray + score)
        end
      when 'add'
        host = args[1]
        @remotes.add(host)
        @log.info("Remote added: #{host}")
      when 'remove'
        host = args[1]
        @remotes.remove(host)
        @log.info("Remote removed: #{host}")
      when 'update'
        update
      else
        raise "Command '#{command}' is not supported"
      end
    end

    def update
      require 'net/http'
      @remotes.all.each do |r|
        uri = URI("http://#{r[:address]}:#{r[:port]}/score.json")
        body = Net::HTTP.get(uri)
        json = JSON.parse(body)
      end
    end
  end
end
