# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'txn'

# Transactions in a wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # A collection of transactions
  class Txns
    # When can't parse them.
    class CantParse < StandardError; end

    def initialize(file)
      @file = file
    end

    def flush
      # nothing
    end

    def fetch
      raise "Wallet file '#{@file}' is absent" unless File.exist?(@file)
      txns = []
      i = 0
      File.open(@file) do |f|
        until f.eof?
          line = f.readline
          i += 1
          next if i < 5
          next if line.strip.empty?
          txns << Txn.parse(line, i)
        end
      end
      raise CantParse, "Not enough lines in #{@file}, just #{i}" if i < 4
      txns.sort
    end
  end

  # Cached transactions.
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2018-2026 Zerocracy
  # License:: MIT
  class CachedTxns
    def initialize(txns)
      @txns = txns
    end

    def flush
      @fetch = nil
    end

    def fetch
      @fetch ||= @txns.fetch
    end
  end
end
