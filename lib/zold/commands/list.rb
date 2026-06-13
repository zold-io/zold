# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'thread_badge'
require 'loog'
require_relative '../amount'
require_relative '../wallet'
require_relative '../size'

# LIST command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # LIST command
  class List
    prepend ThreadBadge

    def initialize(wallets:, copies:, log: Loog::NULL)
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
