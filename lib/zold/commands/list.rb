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

require_relative 'thread_badge'
require_relative '../log'
require_relative '../amount'
require_relative '../wallet'
require_relative '../size'

# LIST command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # LIST command
  class List
    prepend ThreadBadge

    def initialize(wallets:, copies:, log: Log::NULL)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(_ = [])
      total = 0
      txns = 0
      size = 0
      balance = Amount::ZERO
      @wallets.all.sort.each do |id|
        total += 1
        cps = Copies.new(File.join(@copies, id))
        @wallets.acq(id) do |wallet|
          msg = "#{wallet.mnemo} #{cps.all.count}c"
          msg += " (net:#{wallet.network})" if wallet.network != Wallet::MAINET
          txns += wallet.txns.count
          balance += wallet.balance
          size += wallet.size
          @log.info(msg)
        end
      end
      @log.info("#{total} wallets, #{txns} transactions, #{Size.new(size)}, #{balance} in total")
    end
  end
end
