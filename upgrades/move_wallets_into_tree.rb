# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Move wallets into tree
  class MoveWalletsIntoTree
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless path =~ /^[a-f0-9]{16}#{Wallet::EXT}$/
        f = File.join(@home, path)
        target = File.join(@home, (path.split('', 5).take(4) + [path]).join('/'))
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.mv(f, target)
        @log.info("Wallet #{path} moved to #{target}")
      end
    end
  end
end
