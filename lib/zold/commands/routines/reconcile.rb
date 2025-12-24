# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'shellwords'
require_relative '../routines'
require 'loog'
require_relative '../../id'
require_relative '../../copies'
require_relative '../pull'

# R
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Reconcile
  def initialize(opts, wallets, remotes, copies, address, log: Loog::NULL)
    @opts = opts
    @wallets = wallets
    @remotes = remotes
    @copies = copies
    @address = address
    @log = log
  end

  def exec(_ = 0)
    sleep(20 * 60) unless @opts['routine-immediately']
    @remotes.iterate(@log) do |r|
      next unless r.master?
      next if r.to_mnemo == @address
      res = r.http('/wallets').get
      r.assert_code(200, res)
      missing = res.body.strip.split("\n").compact
        .grep(/^[a-f0-9]{16}$/)
        .reject { |i| @wallets.acq(Zold::Id.new(i), &:exists?) }
      missing.each { |i| pull(i) }
      if missing.empty?
        log.info("Nothing to reconcile with #{r}, we are good at #{@address}")
      else
        @log.info("Reconcile routine pulled #{missing.count} wallets from #{r}")
      end
    end
  end

  private

  def pull(id)
    Zold::Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
      ['pull', "--network=#{Shellwords.escape(@opts['network'])}", id.to_s, '--quiet-if-absent']
    )
  end
end
