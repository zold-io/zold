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

require 'uri'
require 'json'
require 'time'
require 'tempfile'
require 'slop'
require 'rainbow'
require_relative 'args'
require_relative '../log'
require_relative '../http'
require_relative '../score'
require_relative '../copies'

# FETCH command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # FETCH pulling command
  class Fetch
    def initialize(wallets:, remotes:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold fetch [ID...] [options]
Available options:"
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak',
          default: false
        o.array '--ignore-node',
          'Ignore this node and don\'t fetch from it',
          default: []
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      mine = @wallets.all if mine.empty?
      mine.each do |id|
        fetch(id, Copies.new(File.join(@copies, id)), opts)
      end
    end

    private

    def fetch(id, cps, opts)
      total = 0
      @remotes.iterate(@log) do |r|
        fetch_one(id, r, cps, opts)
        total += 1
      end
      @log.debug("#{total} copies of #{id} fetched, there are #{cps.all.count} available locally")
    end

    def fetch_one(id, r, cps, opts)
      start = Time.now
      if opts['ignore-node'].include?(r.to_s)
        @log.info("#{r} ignored because of --ignore-node")
        return false
      end
      res = r.http("/wallet/#{id}").get
      raise "Wallet #{id} not found" if res.code == '404'
      r.assert_code(200, res)
      json = JSON.parse(res.body)
      score = Score.parse_json(json['score'])
      r.assert_valid_score(score)
      raise "Score is too weak #{score.strength}" if score.strength < Score::STRENGTH && !opts['ignore-score-weakness']
      Tempfile.open do |f|
        body = json['body']
        File.write(f, body)
        wallet = Wallet.new(f.path)
        cps.add(body, score.host, score.port, score.value)
        @log.info("#{r} returned #{body.length}b/#{wallet.txns.count} \
of #{id} in #{(Time.now - start).round(2)}s: #{Rainbow(score.value).green} (#{json['version']})")
      end
    end
  end
end
