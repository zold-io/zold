# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
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
require_relative 'verbose_thread'

# Background routines.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Metronome
  class Metronome
    def initialize(log = Log::NULL)
      @log = log
      @routines = []
      @threads = []
      @starts = {}
      @failures = {}
    end

    def to_text
      [
        Time.now.utc.iso8601,
        'Current threads:',
        @threads.map do |t|
          [
            "#{t.name}: status=#{t.status}; alive=#{t.alive?}",
            "Most recent start: #{Age.new(@starts[t])} ago",
            t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
          ].join("\n")
        end,
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
        @threads << Thread.start do
          Thread.current.abort_on_exception = true
          Thread.current.name = "#{r.class.name}-#{idx}"
          step = 0
          loop do
            @starts[Thread.current] = Time.now
            begin
              r.exec(step)
              @log.debug("Routine #{r.class.name} ##{step} done in #{Age.new(@starts[Thread.current])}")
            rescue StandardError => e
              @failures[r.class.name] = Time.now.utc.iso8601 + "\n" + Backtrace.new(e).to_s
              @log.error("Routine #{r.class.name} ##{step} failed in #{Age.new(@starts[Thread.current])}")
              @log.error(Backtrace.new(e).to_s)
            end
            step += 1
            sleep(1)
          end
        end
      end
      begin
        yield(self)
      ensure
        start = Time.now
        unless @threads.empty?
          @log.info("Stopping the metronome with #{@threads.count} threads...")
          @threads.each(&:kill)
          @threads.each(&:join)
          @log.info("Metronome #{@threads.count} threads killed")
        end
        @log.info("Metronome stopped in #{Age.new(start)}, #{@failures.count} failures")
      end
    end
  end
end
