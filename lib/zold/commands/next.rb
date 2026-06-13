# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'zold/score'
require_relative 'thread_badge'
require 'loog'

# NEXT command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Calculate next score
  class Next
    prepend ThreadBadge

    def initialize(log: Loog::NULL)
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold next [options] score
Available options:"
        o.bool '--low-priority',
          'Set the lowest priority to this process',
          default: false
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      calculate(opts)
    end

    private

    def calculate(opts)
      Process.setpriority(Process::PRIO_PROCESS, 0, 20) if opts['low-priority']
      @log.info(Score.parse(opts.arguments.drop_while { |a| a.start_with?('--') }[1]).next.to_s)
    end
  end
end
