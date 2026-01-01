# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'txn'

# Head of a wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Head of the wallet.
  class Head
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
      lines = []
      File.open(@file) do |f|
        lines << f.readline.strip while lines.count < 4 && !f.eof?
      end
      raise CantParse, "Not enough lines in #{@file}, just #{lines.count}" if lines.count < 4
      lines
    end
  end

  # Cached head.
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2018-2026 Zerocracy
  # License:: MIT
  class CachedHead
    def initialize(head)
      @head = head
    end

    def flush
      @fetch = nil
    end

    def fetch
      @fetch ||= @head.fetch
    end
  end
end
