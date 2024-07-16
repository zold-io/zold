# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'backtrace'
require_relative 'log'
require_relative 'age'
require_relative 'endless'
require_relative 'verbose_thread'
require_relative 'thread_pool'

# Background routines.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
module Zold
  # Metronome
  class Metronome
    def initialize(log = Log::NULL)
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
