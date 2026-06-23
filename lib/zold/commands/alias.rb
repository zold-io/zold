# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'rainbow'
require 'slop'
require_relative 'args'
require_relative 'thread_badge'
require 'loog'

module Zold
  # Command to set an alias for wallet ID
  class Alias
    prepend ThreadBadge

    def initialize(wallets:, log: Loog::NULL)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = # rubocop:disable Elegant/NoRedundantVariable
        Slop.parse(args, help: true, suppress_errors: true) do |o|
          o.banner = <<~BANNER
            Usage: zold alias [args]
                #{Rainbow('alias set <wallet> <alias>').green}
                  Make wallet known under an alias.
                #{Rainbow('alias remove <alias>').green}
                  Remove an alias.
                #{Rainbow('alias show <alias>').green}
                  Show where the alias is pointing to.
            Available options:
          BANNER
          o.bool('--help', 'Print instructions')
        end
      unless (Args.new(opts, @log).take || return).first
        raise(RuntimeError, "A command is required, try 'zold alias --help'")
      end
      # @todo #279:30min Implement command handling. As in other commands,
      raise(NotImplementedError, 'This is not yet implemented')
    end
  end
end
