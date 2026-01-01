# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'get_process_mem'
require 'loog'
require_relative 'size'

# Verbose thread.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Verbose thread
  class VerboseThread
    def initialize(log = Loog::NULL)
      @log = log
    end

    def run(safe: false)
      Thread.current.report_on_exception = false
      yield
    rescue Errno::ENOMEM => e
      @log.error(Backtrace.new(e).to_s)
      @log.error("We are too big in memory (#{Size.new(GetProcessMem.new.bytes.to_i)}), quitting; \
this is not a normal behavior, you may want to report a bug to our GitHub repository")
      abort
    rescue StandardError => e
      @log.error(Backtrace.new(e).to_s)
      raise e unless safe
    end
  end
end
