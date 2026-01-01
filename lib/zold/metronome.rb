# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'loog'
require_relative 'age'
require_relative 'endless'
require_relative 'verbose_thread'
require_relative 'thread_pool'

# Background routines.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Metronome
  class Metronome
    def initialize(log = Loog::NULL)
      @log = log
      @routines = []
      @threads = ThreadPool.new('metronome', log: log)
      @failures = {}
    end

    def to_text
      [
        Time.now.utc.iso8601,
        'Current threads:',
        @threads.to_s,
        'Failures:',
        @failures.map { |r, f| "#{r}\n#{f}\n" }
      ].flatten.join("\n\n")
    end

    def add(routine)
      @routines << routine
      @log.info("Added #{routine.class.name} to the metronome")
    end

    def start
      @routines.each_with_index do |r, idx|
        @threads.add do
          step = 0
          Endless.new("#{r.class.name}-#{idx}", log: @log).run do
            Thread.current.thread_variable_set(:start, Time.now)
            step += 1
            begin
              r.exec(step)
              @log.debug("Routine #{r.class.name} ##{step} done \
in #{Age.new(Thread.current.thread_variable_get(:start))}")
            rescue StandardError => e
              @failures[r.class.name] = "#{Time.now.utc.iso8601}\n#{Backtrace.new(e)}"
              @log.error("Routine #{r.class.name} ##{step} failed \
in #{Age.new(Thread.current.thread_variable_get(:start))}")
              raise e
            end
            sleep(1)
          end
        end
      end
      begin
        yield(self)
      ensure
        @threads.kill
      end
    end
  end
end
