# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'shellwords'
require_relative 'thread_badge'
require_relative 'args'
require 'loog'
require_relative '../prefixes'

# INVOICE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Generate invoice
  class Invoice
    prepend ThreadBadge

    def initialize(wallets:, remotes:, copies:, log: Loog::NULL)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold invoice ID [options]
Where:
    'ID' is the wallet ID of the money receiver
Available options:"
        o.integer '--length',
          'The length of the invoice prefix (default: 8)',
          default: 8
        o.bool '--tolerate-edges',
          'Don\'t fail if only "edge" (not "master" ones) nodes have the wallet',
          default: false
        o.integer '--tolerate-quorum',
          'The minimum number of nodes required for a successful fetch (default: 4)',
          default: 4
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'Receiver wallet ID is required' if mine[0].nil?
      invoice(Id.new(mine[0]), opts)
    end

    private

    def invoice(id, opts)
      unless @wallets.acq(id, &:exists?)
        require_relative 'pull'
        Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
          ['pull', id.to_s, "--network=#{Shellwords.escape(opts['network'])}"] +
          ["--tolerate-quorum=#{Shellwords.escape(opts['tolerate-quorum'])}"] +
          (opts['tolerate-edges'] ? ['--tolerate-edges'] : [])
        )
      end
      inv = @wallets.acq(id) do |wallet|
        "#{Prefixes.new(wallet).create(opts[:length])}@#{wallet.id}"
      end
      @log.info(inv)
      inv
    end
  end
end
