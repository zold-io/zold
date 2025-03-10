# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../log'
require_relative '../age'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../prefixes'

# PROPAGATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # PROPAGATE pulling command
  class Propagate
    prepend ThreadBadge

    def initialize(wallets:, log: Log::NULL)
      @wallets = wallets
      @log = log
    end

    # Returns list of Wallet IDs which were affected
    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold propagate [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      modified = []
      (mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }).each do |id|
        modified += propagate(id, opts)
      end
      modified
    end

    private

    # Returns list of Wallet IDs which were affected
    def propagate(id, _)
      start = Time.now
      modified = []
      total = 0
      network = @wallets.acq(id, &:network)
      @wallets.acq(id, &:txns).select { |t| t.amount.negative? }.each do |t|
        total += 1
        if t.bnf == id
          @log.error("Paying itself in #{id}? #{t}")
          next
        end
        @wallets.acq(t.bnf, exclusive: true) do |target|
          unless target.exists?
            @log.debug("#{t.amount * -1} from #{id} to #{t.bnf}: wallet is absent")
            next
          end
          unless target.network == network
            @log.debug("#{t.amount * -1} to #{t.bnf}: network mismatch, '#{target.network}'!='#{network}'")
            next
          end
          next if target.includes_positive?(t.id, id)
          unless target.prefix?(t.prefix)
            @log.debug("#{t.amount * -1} from #{id} to #{t.bnf}: wrong prefix \"#{t.prefix}\" in \"#{t}\"")
            next
          end
          target.add(t.inverse(id))
          @log.info("#{t.amount * -1} arrived to #{t.bnf}: #{t.details}")
          modified << t.bnf
        end
      end
      modified.uniq!
      @log.debug("Wallet #{id} propagated successfully, #{total} txns \
in #{Age.new(start, limit: 20 + (total * 0.005))}, #{modified.count} wallets affected")
      modified.each do |w|
        @wallets.acq(w, &:refurbish)
      end
      modified
    end
  end
end
