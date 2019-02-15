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
require_relative 'thread_badge'
require_relative 'args'
require_relative '../age'
require_relative '../log'
require_relative '../id'
require_relative '../wallet'
require_relative '../patch'

# REBASE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # REBASE command
  class Rebase
    prepend ThreadBadge

    def initialize(wallets:, log: Log::NULL)
      @wallets = wallets
      @log = log
    end

    # Returns the array of modified wallets (IDs)
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold rebase [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      list = mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }
      modified = []
      list.uniq.each do |id|
        modified << id if rebase(id, opts)
      end
      modified
    end

    private

    def rebase(id, _)
      start = Time.now
      patch = Patch.new(@wallets, log: @log)
      @wallets.acq(id, exclusive: true) do |wallet|
        patch.join(wallet) do |txn|
          @log.debug("Paying wallet #{txn.bnf} file is absent: #{txn.to_text}")
          false
        end
        if patch.save(wallet.path, overwrite: true)
          @log.info("Wallet #{wallet.mnemo} rebased and modified in #{Age.new(start)}")
        else
          @log.debug("There is nothing to rebase in #{wallet.mnemo}, took #{Age.new(start)}")
        end
      end
    end
  end
end
