# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'rainbow'
require 'slop'
require_relative 'args'
require_relative 'thread_badge'
require 'loog'
require_relative '../age'
require_relative '../amount'
require_relative '../id'
require_relative '../size'
require_relative '../tax'
require_relative '../wallet'

# SHOW command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Show command
  class Show
    prepend ThreadBadge

    def initialize(wallets:, copies:, log: Loog::NULL)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts =
        Slop.parse(args, help: true, suppress_errors: true) do |o|
          o.banner = <<~BANNER
            Usage: zold show [ID...] [options]
            Available options:
          BANNER
          o.bool('--help', 'Print instructions')
        end
      mine = Args.new(opts, @log).take || return
      if mine.empty?
        require_relative('list')
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
      @log.info(
        [
          '',
          "The balance of #{wallet}: #{balance} (#{balance.to_zents} zents)",
          "Network: #{wallet.network}",
          "Transactions: #{wallet.txns.count}",
          "Taxes: #{Tax.new(wallet).paid} paid, the debt is #{Tax.new(wallet).debt}",
          "File size: #{Size.new(wallet.size)}, #{Copies.new(File.join(@copies, wallet.id)).all.count} copies",
          "Modified: #{wallet.mtime.utc.iso8601} (#{Age.new(wallet.mtime.utc.iso8601)} ago)",
          "Digest: #{wallet.digest}"
        ].join("\n")
      )
      msg = Copies.new(File.join(@copies, wallet.id)).all.map do |c| # rubocop:disable Elegant/NoRedundantVariable
        "##{c[:name]}: #{c[:score]} #{Wallet.new(c[:path]).mnemo}"
      end.join("\n")
      @log.info("\n#{msg}")
      balance
    end
  end
end
