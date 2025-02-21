# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'shellwords'
require_relative '../routines'
require_relative '../remote'
require_relative '../../node/farm'

# Kill the node if it's too old.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Retire
  def initialize(opts, log: Log::NULL)
    @opts = opts
    @log = log
    @start = Time.now
  end

  def exec(step = 0)
    sleep(60) unless @opts['routine-immediately']
    days = 4
    return if step < days * 24 * 60 && Time.now - @start < days * 24 * 60 * 60
    return if @opts['never-reboot']
    @log.info("We are too old, step ##{step}, it's time to retire (use --never-reboot to avoid this)")
    require_relative '../../node/front'
    Zold::Front.stop!
  end
end
