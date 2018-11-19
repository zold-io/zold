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
require_relative 'args'
require_relative '../log'
require_relative '../id'
require_relative '../amount'
require_relative '../wallet'

# SHOW command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Show command
  class Show
    def initialize(wallets:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold show [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      if mine.empty?
        require_relative 'list'
        List.new(wallets: @wallets, copies: @copies, log: @log).run(args)
      else
        total = Amount::ZERO
        mine.map { |i| Id.new(i) }.each do |id|
          @wallets.acq(id) do |w|
            total += show(w, opts)
          end
        end
        total
      end
    end

    private

    def show(wallet, _)
      balance = wallet.balance
      wallet.txns.each do |t|
        @log.info(t.to_text)
      end
      msg = "The balance of #{wallet}: #{balance}"
      msg += " (net:#{wallet.network})" if wallet.network != Wallet::MAINET
      @log.info(msg)
      balance
    end
  end
end
