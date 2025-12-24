# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../routines'
require 'loog'
require_relative '../remove'

# Garbage collecting. It goes through the list of all wallets and removes
# those that are older than 10 days and don't have any transactions inside.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Gc
  def initialize(opts, wallets, log: Loog::NULL)
    @opts = opts
    @wallets = wallets
    @log = log
  end

  def exec(_ = 0)
    sleep(60) unless @opts['routine-immediately']
    cmd = Zold::Remove.new(wallets: @wallets, log: @log)
    args = ['remove']
    seen = 0
    removed = 0
    @wallets.all.each do |id|
      seen += 1
      next unless @wallets.acq(id) { |w| w.exists? && w.mtime < Time.now - @opts['gc-age'] && w.txns.empty? }
      cmd.run(args + [id.to_s])
      removed += 1
    end
    @log.info("Removed #{removed} empty+old wallets out of #{seen} total") unless removed.zero?
  end
end
