# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'logger'

# The log of the Thin web server.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Thin writes its own messages through a global logger, which prints them
  # to the console by default; this one sends them to the Zold log instead.
  class ThinLog < Logger
    def initialize(log)
      super(nil, level: Logger::INFO)
      @log = log
    end

    def add(severity, msg = nil, progname = nil)
      text = msg || (block_given? ? yield : progname)
      case severity
      when Logger::DEBUG then @log.debug(text)
      when Logger::INFO then @log.info(text)
      else @log.error(text)
      end
      true
    end
  end
end
