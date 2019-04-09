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

require 'slop'
require 'rainbow'
require 'backtrace'
require 'shellwords'
require_relative 'thread_badge'
require_relative 'args'
require_relative 'pull'
require_relative '../age'
require_relative '../log'
require_relative '../id'
require_relative '../wallet'
require_relative '../patch'

# MERGE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # MERGE command
  class Merge
    prepend ThreadBadge

    def initialize(home:, log: Log::NULL)
      @home = home
      @wallets = @home.wallets
      @remotes = @home.remotes
      @copies = @home.copies
      @log = log
    end

    # Returns the array of modified wallets (IDs)
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold merge [ID...] [options]
Available options:"
        o.bool '--skip-propagate',
          'Don\'t propagate after merge',
          default: false
        o.bool '--skip-legacy',
          'Don\'t make legacy transactions (older than 24 hours) immutable',
          default: false
        o.bool '--quiet-if-absent',
          'Don\'t fail if the wallet is absent',
          default: false
        o.integer '--depth',
          'How many levels down we try to pull other wallets if their confirmations are required (default: 0)',
          default: 0
        o.bool '--allow-negative-balance',
          'Don\'t check for the negative balance of the wallet after the merge',
          default: false
        o.bool '--no-baseline',
          'Don\'t treat the highest score master copy as trustable baseline',
          default: false
        o.bool '--edge-baseline',
          'Use any strongest group of nodes as baseline, even if there are no masters inside (dangerous!)',
          default: false
        o.string '--ledger',
          'The name of the file where all new negative transactions will be recorded (default: /dev/null)',
          default: '/dev/null'
        o.string '--trusted',
          'The name of the file with a list of wallet IDs we fully trust and won\'t pull',
          default: '/dev/null'
        o.integer '--trusted-max',
          'The maximum amount of trusted wallets we can see in the list',
          default: 128
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      modified = []
      list = mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }
      list.uniq.each do |id|
        next unless merge(id, Copies.new(File.join(@copies, id)), opts)
        modified << id
        next if opts['skip-propagate']
        require_relative 'propagate'
        modified += Propagate.new(wallets: @wallets, log: @log).run(args)
      end
      modified
    end

    private

    def merge(id, cps, opts)
      start = Time.now
      cps = cps.all(masters_first: !opts['edge-baseline'])
      patch = Patch.new(@wallets, log: @log)
      score = 0
      unless opts['skip-legacy']
        @wallets.acq(id) do |w|
          if w.exists?
            s = Time.now
            patch.legacy(w)
            @log.debug("Local copy of #{id} merged legacy in #{Age.new(s)}: #{patch}")
          else
            @log.debug("There is no local copy to merge legacy of #{id}")
          end
        end
      end
      cps.each_with_index do |c, idx|
        wallet = Wallet.new(c[:path])
        baseline = idx.zero? && (c[:master] || opts['edge-baseline']) && !opts['no-baseline']
        name = "#{c[:name]}/#{idx}/#{c[:score]}#{baseline ? '/baseline' : ''}"
        merge_one(opts, patch, wallet, name, baseline: baseline)
        score += c[:score]
      end
      @wallets.acq(id) do |w|
        if w.exists?
          s = Time.now
          merge_one(opts, patch, w, 'localhost')
          @log.debug("Local copy of #{id} merged in #{Age.new(s)}: #{patch}")
        else
          @log.debug("Local copy of #{id} is absent, nothing to merge")
        end
      end
      if patch.empty?
        return if opts['quiet-if-absent']
        raise "There are no copies of #{id}, nothing to merge"
      end
      modified = @wallets.acq(id, exclusive: true) do |w|
        patch.save(w.path, overwrite: true, allow_negative_balance: opts['allow-negative-balance'])
      end
      if modified
        @log.info("#{cps.count} copies with the total score of #{score} successfully merged \
into #{@wallets.acq(id, &:mnemo)} in #{Age.new(start, limit: 0.1 + cps.count * 0.01)}")
      else
        @log.info("Nothing changed in #{id} after merge of #{cps.count} copies")
      end
      modified
    end

    def merge_one(opts, patch, wallet, name, baseline: false)
      start = Time.now
      @log.debug("Building a patch for #{wallet.id} from remote copy ##{name} with #{wallet.mnemo}...")
      if opts['depth'].positive?
        patch.join(wallet, ledger: opts['ledger'], baseline: baseline) do |txn|
          trusted = IO.read(opts['trusted']).split(',')
          if trusted.include?(txn.bnf.to_s)
            @log.debug("Won't PULL #{txn.bnf} since it is already trusted, among #{trusted.count} others")
          elsif trusted.count > opts['trusted-max']
            @log.debug("Won't PULL #{txn.bnf} since there are too many trusted wallets already: \
#{trusted.count} > #{opts['trusted-max']}")
          else
            IO.write(opts['trusted'], (trusted + [txn.bnf.to_s]).sort.uniq.join(','))
            home = Zold::Home.new(wallets: @wallets, remotes: @remotes, copies: @copies)
            Pull.new(home: home, log: @log).run(
              ['pull', txn.bnf.to_s, "--network=#{Shellwords.escape(opts['network'])}", '--quiet-if-absent'] +
              ["--depth=#{opts['depth'] - 1}"] +
              (opts['no-baseline'] ? ['--no-baseline'] : []) +
              (opts['edge-baseline'] ? ['--edge-baseline'] : []) +
              ["--trusted=#{Shellwords.escape(opts['trusted'])}"]
            )
          end
          true
        end
      else
        patch.join(wallet, ledger: opts['ledger'], baseline: baseline) do |txn|
          @log.debug("Paying wallet #{txn.bnf} is incomplete but there is not enough depth to PULL: #{txn.to_text}")
          false
        end
      end
      @log.debug("Copy ##{name} of #{wallet.id} merged in #{Age.new(start)}: #{patch}")
    rescue StandardError => e
      @log.error("Can't merge copy #{name}: #{e.message}")
      @log.debug(Backtrace.new(e).to_s)
    end
  end
end
