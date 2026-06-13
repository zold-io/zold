# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Upgrade protocol in each wallet
  class ProtocolUp
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless /^[a-f0-9]{16}#{Wallet::EXT}$/o.match?(path)
        f = File.join(@home, path)
        lines = File.read(f).split("\n")
        next if lines[1].to_i == Zold::PROTOCOL
        lines[1] = Zold::PROTOCOL
        File.write(f, lines.join("\n"))
        @log.info("Protocol set to #{Zold::PROTOCOL} in #{f}")
      end
    end
  end
end
