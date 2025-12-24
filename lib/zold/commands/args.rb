# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'json'
require 'net/http'
require 'loog'
require_relative '../id'
require_relative '../http'

# Args.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Command line args
  class Args
    def initialize(opts, log)
      @opts = opts
      @log = log
    end

    def take
      if @opts.help?
        @log.info(@opts.to_s)
        return
      end
      args = @opts.arguments.reject { |a| a.start_with?('-') }
      raise 'Try --help' if args.empty?
      args[1..-1]
    end
  end
end
