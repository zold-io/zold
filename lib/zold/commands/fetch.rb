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
require_relative '../json_page'
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
        o.banner = <<~HELP.chomp
          Usage: zold fetch [ID...] [options]
          Available options:
        HELP
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
      mine.map { |i| Id.new(i) }.each do |id|
        fetch(id, Copies.new(File.join(@copies, id)), opts)
      end
    end

    private

    def fetch(id, cps, opts)
      total = 0
      nodes = 0
      done = 0
      @remotes.iterate(@log) do |r|
        nodes += 1
        total += fetch_one(id, r, cps, opts)
        done += 1
      end
      raise "There are no remote nodes, run 'zold remote reset'" if nodes.zero?
      raise "No nodes out of #{nodes} have the wallet #{id}" if done.zero?
      @log.debug("#{nodes} copies of #{id} fetched for the total score of #{total}, \
#{cps.all.count} local copies:\n  #{cps.all.map { |c| "#{c[:name]}: #{c[:score]}" }.join("\n  ")}")
    end

    def fetch_one(id, r, cps, opts)
      start = Time.now
      if opts['ignore-node'].include?(r.to_s)
        @log.debug("#{r} ignored because of --ignore-node")
        return 0
      end
      res = r.http("/wallet/#{id}").get
      raise "Wallet #{id} not found" if res.code == '404'
      r.assert_code(200, res)
      json = JsonPage.new(res.body).to_hash
      score = Score.parse_json(json['score'])
      r.assert_valid_score(score)
      r.assert_score_ownership(score)
      r.assert_score_strength(score) unless opts['ignore-score-weakness']
      Tempfile.open(['', Wallet::EXTENSION]) do |f|
        body = json['body']
        File.write(f, body)
        wallet = Wallet.new(f.path)
        copy = cps.add(body, score.host, score.port, score.value)
        @log.info("#{r} returned #{body.length}b/#{wallet.txns.count}t/#{digest(json)}/#{age(json)} as copy #{copy} \
of #{id} in #{(Time.now - start).round(2)}s: #{Rainbow(score.value).green} (#{json['version']})")
      end
      score.value
    end

    def digest(json)
      hash = json['digest']
      return '?' if hash.nil?
      hash[0, 6]
    end

    def age(json)
      mtime = json['mtime']
      return '?' if mtime.nil?
      sec = Time.now - Time.parse(mtime)
      if sec < 60
        "#{sec}s"
      elsif sec < 60 * 60
        "#{(sec / 60).round}m"
      else
        "#{(sec / 3600).round}h"
      end
    end
  end
end
