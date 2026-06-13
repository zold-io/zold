# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'thread_badge'
require 'loog'
require_relative 'fetch'
require_relative 'merge'
require_relative 'clean'

# PULL command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # PULL command
  class Pull
    prepend ThreadBadge

    def initialize(wallets:, remotes:, copies:, log: Loog::NULL)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(args = [])
      Zold::Clean.new(wallets: @wallets, copies: @copies, log: @log).run(args)
      Zold::Fetch.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(args)
      Zold::Merge.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(args)
    end
  end
end
