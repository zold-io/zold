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
require 'json'
require 'net/http'
require_relative '../log'
require_relative '../id'
require_relative '../http'

# PUSH command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Wallet pushing command
  class Push
    def initialize(wallets:, remotes:, log: Log::Quiet.new)
      @wallets = wallets
      @remotes = remotes
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true) do |o|
        o.banner = "Usage: zold push [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise 'At least one wallet ID is required' if opts.arguments.empty?
      opts.arguments.each do |id|
        push(@wallets.find(Id.new(id)), opts)
      end
    end

    def push(wallet, _)
      raise 'The wallet is absent' unless wallet.exists?
      total = 0
      @remotes.all.each do |r|
        uri = URI("#{r[:home]}wallet/#{wallet.id}")
        response = Http.new(uri).put(File.read(wallet.path))
        if response.code == '304'
          @log.info("#{uri}: same version there")
          next
        end
        unless response.code == '200'
          @log.error("#{uri} failed as #{response.code}/#{response.message}")
          next
        end
        json = JSON.parse(response.body)['score']
        score = Score.new(
          Time.parse(json['time']), json['host'],
          json['port'], json['suffixes']
        )
        unless score.valid?
          @log.error("#{uri} invalid score")
          next
        end
        total += score.value
      end
      @log.info("Total score is #{total}")
    end
  end
end
