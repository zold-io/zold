# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'rainbow'
require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Delete wallets which are in the banned-wallets.csv file
  class DeleteBannedWallets
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      DirItems.new(@home).fetch.each do |path|
        name = File.basename(path)
        next unless /^[a-f0-9]{16}#{Wallet::EXT}$/o.match?(name)
        id = Id.new(name[0..15])
        next unless Id::BANNED.include?(id.to_s)
        path = File.join(@home, path)
        File.rename(path, "#{path}-banned")
        @log.info("Wallet file #{path} renamed, since wallet #{id} is banned")
      end
    end
  end
end
