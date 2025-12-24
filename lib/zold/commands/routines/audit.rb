# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'get_process_mem'
require_relative '../routines'
require_relative '../../size'

# Audit and report as much as we can to the command line.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Audit
  def initialize(opts, wallets, log: Loog::NULL)
    @opts = opts
    @wallets = wallets
    @log = log
  end

  def exec(_ = 0)
    sleep(60) unless @opts['routine-immediately']
    msg = [
      "memory used: #{Zold::Size.new(GetProcessMem.new.bytes.to_i)}",
      "threads total: #{Thread.list.count}",
      "wallets: #{@wallets.count}"
    ].join('; ')
    @log.info("Audit: #{msg}")
  end
end
