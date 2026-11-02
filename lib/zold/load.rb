# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

# System load average for the last minute.
#
# It is taken from the output of the "uptime" command, which prints
# the load average on Linux, FreeBSD, and macOS alike.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Load average
  class Load
    # When the load average cannot be found in the output
    class CantDetect < StandardError; end

    def initialize(text = `uptime 2>&1`)
      @text = text
    end

    def value
      found = @text.match(/load averages?:\s*(\d+[.,]\d+)/)
      raise(CantDetect, "Cannot find load average in #{@text.strip.inspect}") if found.nil?
      Float(found[1].tr(',', '.'))
    end
  end
end
