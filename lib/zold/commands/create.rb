# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../wallet'
require 'loog'
require_relative '../id'

# CREATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Create command
  class Create
    prepend ThreadBadge

    def initialize(wallets:, remotes:, log: Loog::NULL)
      @wallets = wallets
      @remotes = remotes
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold create [options]
Available options:"
        o.string '--public-key',
          'The location of RSA public key (default: ~/.ssh/id_rsa.pub)',
          require: true,
          default: File.expand_path('~/.ssh/id_rsa.pub')
        o.bool '--skip-test',
          'Don\'t check whether this wallet ID is available',
          default: false
        o.string '--network',
          "The name of the network (default: #{Wallet::MAINET}",
          require: true,
          default: Wallet::MAINET
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      create(mine.empty? ? create_id(opts) : Id.new(mine[0]), opts)
    end

    private

    def create_id(opts)
      loop do
        id = Id.new
        return id if opts['skip-test']
        found = @wallets.exists?(id)
        if found
          @log.debug("Wallet ID #{id} already exists locally, will try another one...")
          next
        end
        @remotes.iterate(@log) do |r|
          head = r.http("/wallet/#{id}/digest").get
          found = true if head.status == 200
        end
        return id unless found
        @log.info("Wallet ID #{id} is already occupied, will try another one...")
      end
    end

    def create(id, opts)
      key = Zold::Key.new(file: opts['public-key'])
      @wallets.acq(id, exclusive: true) do |wallet|
        raise "Wallet #{id} already exists" if wallet.exists?
        wallet.init(id, key, network: opts['network'])
        @log.debug("Wallet #{Rainbow(wallet).green} created at #{@wallets.path}")
      end
      @log.info(id)
      id
    end
  end
end
