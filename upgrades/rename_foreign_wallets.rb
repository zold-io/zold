# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'rainbow'
require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Rename wallets that belong to another network
  class RenameForeignWallets
    def initialize(home, network, log)
      @home = home
      @network = network
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless path =~ /^[a-f0-9]{16}#{Wallet::EXT}$/
        f = File.join(@home, path)
        wallet = Wallet.new(f)
        next if wallet.network == @network
        @log.info("Wallet #{wallet.id} #{Rainbow('renamed').red}, \
since it's in \"#{wallet.network}\", while we are in \"#{@network}\" network")
        File.rename(f, "#{f}-old")
      end
    end
  end
end
