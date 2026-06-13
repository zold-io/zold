# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative 'verbose_thread'
require_relative 'age'

# Endless loop.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Endless loop
  class Endless
    def initialize(title, log: Loog::NULL)
      @title = title
      @log = log
    end

    def run(&block)
      start = Time.now
      Thread.current.name = @title
      begin
        loop do
          VerboseThread.new(@log).run(safe: true, &block)
        end
      ensure
        @log.debug("Endless loop \"#{@title}\" quit after #{Age.new(start)} of work")
      end
    end
  end
end
