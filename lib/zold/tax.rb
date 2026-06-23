# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'amount'
require_relative 'id'
require_relative 'key'
require_relative 'wallet'

# Tax transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # A single tax payment
  class Tax
    EXACT_SCORE = 8

    MAX_PAYMENT = Amount.new(zld: 16.0)

    FEE = Amount.new(zents: 1917)

    TRIAL = Amount.new(zld: 1.0)

    PREFIX = 'TAXES'
    private_constant :PREFIX

    MILESTONES = { Txn.parse_time('2018-11-30T00:00:00Z') => 6, Txn.parse_time('2018-12-09T00:00:00Z') => 7 }.freeze
    private_constant :MILESTONES

    def initialize(wallet, ignore_score_weakness: false, strength: Score::STRENGTH)
      raise(RuntimeError, "The wallet must be of type Wallet: #{wallet.class.name}") unless wallet.is_a?(Wallet)
      @wallet = wallet
      @ignore = ignore_score_weakness
      @strength = strength
    end

    # Check whether this tax payment already exists in the wallet.
    def exists?(details)
      !@wallet.txns.find { |t| t.details.start_with?("#{PREFIX} ") && t.details == details }.nil?
    end

    def details(best)
      "#{PREFIX} #{best.reduced(EXACT_SCORE)}"
    end

    def pay(pvt, best)
      @wallet.sub([MAX_PAYMENT, debt].min, best.invoice, pvt, details(best))
    end

    def in_debt?
      debt > TRIAL
    end

    def to_text
      "A=#{@wallet.age.round} hours, F=#{FEE.to_zents}z/th, T=#{@wallet.txns.count}t, Paid=#{paid}"
    end

    def debt
      (FEE * @wallet.txns.count * @wallet.age) - paid
    end

    def paid
      txns = @wallet.txns
      scored = txns.map do |t| # rubocop:disable Elegant/NoRedundantVariable
        next if t.amount.positive?
        pfx, body = t.details.split(' ', 2)
        next if pfx != PREFIX || body.nil?
        score = Score.parse(body)
        next unless score.valid?
        next unless score.value == EXACT_SCORE || @ignore
        if score.strength < @strength && !@ignore && !MILESTONES.find { |d, s| t.date < d && score.strength >= s }
          next
        end
        next if t.amount * -1 > MAX_PAYMENT
        t
      end.compact.uniq(&:details)
      scored.sum(Amount::ZERO, &:amount) * -1
    end
  end
end
