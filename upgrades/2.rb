# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

# https://github.com/zold-io/zold/issues/358
# rename all wallets from their current names into *.z

module Zold
  # Upgrade to version 2
  class UpgradeTo2
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless path =~ /^[a-f0-9]{16}$/
        File.rename(path, "#{path}.z")
        @log.info("Renamed #{path} to #{path}.z")
      end
    end
  end
end
