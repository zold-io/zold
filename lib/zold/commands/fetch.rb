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

require 'uri'
require 'json'
require 'time'
require 'tempfile'
require 'slop'
require 'rainbow'
require 'concurrent/atomics'
require 'zold/score'
require 'concurrent'
require 'parallel'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../thread_pool'
require_relative '../log'
require_relative '../age'
require_relative '../http'
require_relative '../size'
require_relative '../json_page'
require_relative '../copies'

# FETCH command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # FETCH pulling command
  class Fetch
    prepend ThreadBadge

    # Raises when there are only edge nodes and not a single master one.
    class EdgesOnly < StandardError; end

    # Raises when there are not enough successful nodes.
    class NoQuorum < StandardError; end

    def initialize(wallets:, remotes:, copies:, log: Log::NULL)
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
        o.bool '--tolerate-edges',
          'Don\'t fail if only "edge" (not "master" ones) nodes accepted the wallet',
          default: false
        o.integer '--tolerate-quorum',
          'The minimum number of nodes required for a successful fetch (default: 4)',
          default: 4
        o.bool '--quiet-if-absent',
          'Don\'t fail if the wallet is absent in all remote nodes',
          default: false
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.integer '--threads',
          "How many threads to use for fetching wallets (default: #{[Concurrent.processor_count / 2, 2].max})",
          default: [Concurrent.processor_count / 2, 2].max
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      list = mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }
      ThreadPool.new('fetch', log: @log).run(opts['threads'], list) do |id|
        fetch(id, Copies.new(File.join(@copies, id)), opts)
      end
    end

    private

    def fetch(id, cps, opts)
      raise "There are no remote nodes, run 'zold remote reset'" if @remotes.all.empty?
      start = Time.now
      total = Concurrent::AtomicFixnum.new
      nodes = Concurrent::AtomicFixnum.new
      done = Concurrent::AtomicFixnum.new
      masters = Concurrent::AtomicFixnum.new
      @remotes.iterate(@log) do |r|
        nodes.increment
        total.increment(fetch_one(id, r, cps, opts))
        masters.increment if r.master?
        done.increment
      end
      unless opts['quiet-if-absent']
        if done.value.zero?
          raise "No nodes out of #{nodes.value} have the wallet #{id}; run 'zold remote update' and try again"
        end
        if masters.value.zero? && !opts['tolerate-edges']
          raise EdgesOnly, "There are only edge nodes, run 'zold remote update' or use --tolerate-edges"
        end
        if nodes.value < opts['tolerate-quorum']
          raise NoQuorum, "There were not enough nodes, the required quorum is #{opts['tolerate-quorum']}; \
run 'zold remote update' or use --tolerate-quorum=1"
        end
      end
      @log.info("#{done.value} copies of #{id} fetched in #{Age.new(start)} with the total score of \
#{total.value} from #{nodes.value} nodes (#{masters.value} master nodes)")
      list = cps.all.map do |c|
        "  ##{c[:name]}: #{c[:score]} #{Wallet.new(c[:path]).mnemo} \
#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}"
      end
      @log.debug("#{cps.all.count} local copies of #{id}:\n#{list.join("\n")}")
    end

    def fetch_one(id, r, cps, opts)
      start = Time.now
      if opts['ignore-node'].include?(r.to_s)
        @log.debug("#{r} ignored because of --ignore-node")
        return 0
      end
      uri = "/wallet/#{id}"
      size = r.http(uri + '/size').get
      r.assert_code(200, size)
      res = r.http(uri).get(timeout: 2 + size.body.to_i * 0.01 / 1024)
      r.assert_code(200, res)
      json = JsonPage.new(res.body, uri).to_hash
      score = Score.parse_json(json['score'])
      r.assert_valid_score(score)
      r.assert_score_ownership(score)
      r.assert_score_strength(score) unless opts['ignore-score-weakness']
      Tempfile.open(['', Wallet::EXT]) do |f|
        body = json['body']
        IO.write(f, body)
        wallet = Wallet.new(f.path)
        # wallet.refurbish
        if wallet.protocol != Zold::PROTOCOL
          raise "Protocol #{wallet.protocol} doesn't match #{Zold::PROTOCOL} in #{id}"
        end
        if wallet.network != opts['network']
          raise "The wallet #{id} is in network '#{wallet.network}', while we are in '#{opts['network']}'"
        end
        if wallet.balance.negative? && !wallet.root?
          raise "The balance of #{id} is #{wallet.balance} and it's not a root wallet"
        end
        copy = cps.add(IO.read(f), score.host, score.port, score.value, master: r.master?)
        @log.info("#{r} returned #{wallet.mnemo} #{Age.new(json['mtime'])}/#{json['copies']}c \
as copy ##{copy}/#{cps.all.count} in #{Age.new(start, limit: 4)}: \
#{Rainbow(score.value).green} (#{json['version']})")
      end
      score.value
    end

    def digest(json)
      hash = json['digest']
      return '?' if hash.nil?
      hash[0, 6]
    end
  end
end
