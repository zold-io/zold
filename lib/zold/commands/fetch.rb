# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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
require 'openssl'
require 'rainbow'
require 'concurrent/atomics'
require 'zold/score'
require 'concurrent'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../thread_pool'
require_relative '../hands'
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

    # Raises when fetch fails.
    class Error < StandardError; end

    # Raises when there are only edge nodes and not a single master one.
    class EdgesOnly < Error; end

    # Raises when there are not enough successful nodes.
    class NoQuorum < Error; end

    # Raises when the wallet wasn't found in all visible nodes.
    class NotFound < Error; end

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
          'How many threads to use for fetching wallets (default: 1)',
          default: 1
        o.integer '--retry',
          'How many times to retry each node before reporting a failure (default: 2)',
          default: 2
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      list = mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }
      Hands.exec(opts['threads'], list.uniq) do |id|
        fetch(id, Copies.new(File.join(@copies, id)), opts)
      end
    end

    private

    def fetch(id, cps, opts)
      if @remotes.all.empty?
        return if opts['quiet-if-absent']
        raise "There are no remote nodes, run 'zold remote reset'"
      end
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
          raise NotFound, "No nodes out of #{nodes.value}, incl. #{masters.value} master, have the wallet #{id}; \
run 'zold remote update' and try again"
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
#{total.value} from #{nodes.value - masters.value}+#{masters.value}m nodes")
      list = cps.all.map do |c|
        "  ##{c[:name]}: #{c[:score]} #{c[:total]}n #{Wallet.new(c[:path]).mnemo} \
#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}#{c[:master] ? ' master' : ''}"
      end
      @log.debug("#{cps.all.count} local copies of #{id}:\n#{list.join("\n")}")
    end

    def fetch_one(id, r, cps, opts)
      if opts['ignore-node'].include?(r.to_s)
        @log.debug("#{r} ignored because of --ignore-node")
        return 0
      end
      start = Time.now
      read_one(id, r, opts) do |json, score|
        r.assert_valid_score(score)
        r.assert_score_ownership(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        unless existing_copy_added(id, cps, score, r, json)
          Tempfile.open(['', Wallet::EXT]) do |f|
            r.http("/wallet/#{id}.bin").get_file(f)
            wallet = Wallet.new(f.path)
            wallet.refurbish
            if wallet.protocol != Zold::PROTOCOL
              raise FetchError, "Protocol #{wallet.protocol} doesn't match #{Zold::PROTOCOL} in #{id}"
            end
            if wallet.network != opts['network']
              raise FetchError, "The wallet #{id} is in '#{wallet.network}', while we are in '#{opts['network']}'"
            end
            if wallet.balance.negative? && !wallet.root?
              raise FetchError, "The balance of #{id} is #{wallet.balance} and it's not a root wallet"
            end
            copy = cps.add(File.read(f), score.host, score.port, score.value, master: r.master?)
            @log.debug("#{r} returned #{wallet.mnemo} #{Age.new(json['mtime'])}/#{json['copies']}c \
as copy ##{copy}/#{cps.all.count} in #{Age.new(start, limit: 4)}: \
#{Rainbow(score.value).green} (#{json['version']})")
          end
        end
        score.value
      end
    end

    def read_one(id, r, opts)
      attempt = 0
      begin
        uri = "/wallet/#{id}"
        head = r.http(uri).get
        raise Fetch::Error, "The wallet #{id} doesn't exist at #{r}" if head.status == 404
        r.assert_code(200, head)
        json = JsonPage.new(head.body, uri).to_hash
        score = Score.parse_json(json['score'])
        yield json, score
      rescue JsonPage::CantParse, Score::CantParse, RemoteNode::CantAssert => e
        attempt += 1
        if attempt < opts['retry']
          @log.debug("#{r} failed to fetch #{id}, trying again (attempt no.#{attempt}): #{e.message}")
          retry
        end
        raise e
      end
    end

    def existing_copy_added(id, cps, score, r, json)
      cps.all.each do |c|
        next unless json['digest'] == OpenSSL::Digest::SHA256.file(c[:path]).hexdigest &&
          json['size'] == File.size(c[:path])
        copy = cps.add(File.read(c[:path]), score.host, score.port, score.value, master: r.master?)
        @log.debug("No need to fetch #{id} from #{r}, it's the same content as copy ##{copy}")
        return true
      end
      false
    end

    def digest(json)
      hash = json['digest']
      return '?' if hash.nil?
      hash[0, 6]
    end
  end
end
