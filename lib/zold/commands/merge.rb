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

require 'slop'
require 'rainbow'
require 'backtrace'
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
  # MERGE pulling command
  class Merge
    prepend ThreadBadge

    def initialize(wallets:, remotes:, copies:, log: Log::NULL)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    # Returns the array of modified wallets (IDs)
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold merge [ID...] [options]
Available options:"
        o.bool '--no-baseline',
          'Don\'t trust any remote copies and re-validate all incoming payments against their wallets',
          default: false
        o.bool '--skip-propagate',
          'Don\'t propagate after merge',
          default: false
        o.bool '--skip-legacy',
          'Don\'t make legacy transactions (older than 24 hours) immutable',
          default: false
        o.bool '--shallow',
          'Don\'t try to pull other wallets if their confirmations are required',
          default: false
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      modified = []
      (mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }).each do |id|
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
      cps = cps.all.sort_by { |c| c[:score] }.reverse
      patch = Patch.new(@wallets, log: @log)
      score = 0
      unless opts['skip-legacy']
        @wallets.acq(id) do |w|
          if w.exists?
            s = Time.now
            merge_one(opts, patch, w, 'localhost', legacy: true)
            @log.debug("Local legacy copy of #{id} merged in #{Age.new(s)}: #{patch}")
          end
        end
      end
      cps.each_with_index do |c, idx|
        wallet = Wallet.new(c[:path])
        name = "#{c[:name]}/#{idx}/#{c[:score]}"
        merge_one(opts, patch, wallet, name)
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
      raise "There are no copies of #{id}, nothing to merge" if patch.empty?
      modified = @wallets.acq(id, exclusive: true) { |w| patch.save(w.path, overwrite: true) }
      if modified
        @log.info("#{cps.count} copies with the total score of #{score} successfully merged \
into #{@wallets.acq(id, &:mnemo)} in #{Age.new(start, limit: 0.1 + cps.count * 0.01)}")
      else
        @log.info("Nothing changed in #{id} after merge of #{cps.count} copies")
      end
      modified
    end

    def merge_one(opts, patch, wallet, name, legacy: false)
      start = Time.now
      @log.debug("Building a patch for #{wallet.id} from remote copy ##{name} with #{wallet.mnemo}...")
      patch.join(wallet, baseline: !opts['no-baseline'], legacy: legacy) do |id|
        unless opts['shallow']
          Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
            ['pull', id.to_s, "--network=#{opts['network']}", '--shallow']
          )
        end
      end
      @log.debug("Copy ##{name} of #{wallet.id} merged in #{Age.new(start)}: #{patch}")
    rescue StandardError => e
      @log.error("Can't merge copy #{name}: #{e.message}")
      @log.debug(Backtrace.new(e).to_s)
    end
  end
end
