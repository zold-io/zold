# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require 'loog'

# REMOVe command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # REMOVE command
  class Remove
    prepend ThreadBadge

    def initialize(wallets:, log: Loog::NULL)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold remove [ID...] [options]
Available options:"
        o.bool '--force',
          'Don\'t report any errors if the wallet doesn\'t exist',
          default: false
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      (mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }).each do |id|
        remove(id, opts)
      end
    end

    def remove(id, opts)
      @wallets.acq(id, exclusive: true) do |w|
        if w.exists?
          File.delete(w.path)
        else
          raise "Wallet #{id} doesn't exist in #{w.path}" unless opts['force']
          @log.info("Wallet #{id} file not found in #{w.path}")
        end
      end
      @log.info("Wallet #{id} removed")
    end
  end
end
