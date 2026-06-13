# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Log that traces everything
  class Trace
    def initialize(log, limit = 4096)
      @log = log
      @buffer = []
      @mutex = Mutex.new
      @limit = limit
    end

    def to_s
      @mutex.synchronize do
        @buffer.join("\n")
      end
    end

    def debug(msg)
      @log.debug(msg)
      append('DBG', msg) if debug?
    end

    def debug?
      @log.debug?
    end

    def info(msg)
      @log.info(msg)
      append('INF', msg) if info?
    end

    def info?
      @log.info?
    end

    def error(msg)
      @log.error(msg)
      append('ERR', msg)
    end

    private

    def append(level, msg)
      @mutex.synchronize do
        @buffer << "#{level}: #{msg}"
        @buffer.shift if @buffer.size > @limit
      end
    end
  end
end
