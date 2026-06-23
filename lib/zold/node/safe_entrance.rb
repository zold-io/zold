# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require 'tempfile'
require_relative '../commands/fetch'
require_relative '../commands/merge'
require_relative '../commands/push'
require_relative '../copies'
require_relative '../remotes'
require_relative '../tax'
require_relative 'soft_error'

# The entrance thav validate the incoming wallet first.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # The safe entrance
  class SafeEntrance
    def initialize(entrance, network: 'test')
      raise(RuntimeError, 'Entrance can\'t be nil') if entrance.nil?
      @entrance = entrance
      raise(RuntimeError, 'Network can\'t be nil') if network.nil?
      @network = network
    end

    def start
      raise(RuntimeError, 'Block must be given to start()') unless block_given?
      @entrance.start { yield(self) }
    end

    def to_json(*_args)
      @entrance.to_json
    end

    # Returns a list of modified wallets (as Zold::Id)
    def push(id, body)
      raise(RuntimeError, 'Id can\'t be nil') if id.nil?
      raise(RuntimeError, 'Id must be of type Id') unless id.is_a?(Id)
      raise(RuntimeError, 'Body can\'t be nil') if body.nil?
      Tempfile.open(['', Wallet::EXT]) do |f|
        File.write(f, body)
        wallet = Wallet.new(f.path)
        wallet.refurbish
        unless wallet.protocol == Zold::PROTOCOL
          raise(SoftError, "Protocol mismatch, #{wallet.id} is in '#{wallet.protocol}', we are in '#{Zold::PROTOCOL}'")
        end
        unless wallet.network == @network
          raise(SoftError, "Network name mismatch, #{wallet.id} is in '#{wallet.network}', we are in '#{@network}'")
        end
        balance = wallet.balance
        if balance.negative? && !wallet.root?
          raise(SoftError, "The balance #{balance} of #{wallet.id} is negative and it's not a root wallet")
        end
        tax = Tax.new(wallet)
        if tax.in_debt?
          raise(
            SoftError,
            "Taxes are not paid, can't accept the wallet #{wallet.mnemo}; the debt is #{tax.debt} " \
            "(#{tax.debt.to_zents} zents); formula ingredients are #{tax.to_text}"
          )
        end
        @entrance.push(id, body)
      end
    end
  end
end
