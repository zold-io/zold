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

require 'open3'
require 'backtrace'
require 'zold/score'
require 'shellwords'
require_relative '../log'
require_relative '../age'

# Farmers.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Farmer
  module Farmers
    # Kill a process
    def self.kill(log, pid, start)
      Process.kill('KILL', pid)
      log.debug("Process ##{pid} killed after #{Age.new(start)} of activity")
    rescue StandardError => e
      log.debug("No need to kill process ##{pid} since it's dead already: #{e.message}")
    end

    # Plain and simple
    class Plain
      def initialize(log: Log::NULL)
        @log = log
      end

      def up(score)
        score.next
      end
    end

    # In a child process using fork
    class Fork
      def initialize(log: Log::NULL)
        @log = log
      end

      def up(score)
        start = Time.now
        stdout, stdin = IO.pipe
        pid = Process.fork do
          stdin.puts(score.next)
        end
        at_exit { Farmers.kill(@log, pid, start) }
        Process.wait
        stdin.close
        text = stdout.read.strip
        stdout.close
        raise "No score was calculated in the process ##{pid} in #{Age.new(start)}" if text.empty?
        after = Score.parse(text)
        @log.debug("Next score #{after.value}/#{after.strength} found in proc ##{pid} \
for #{after.host}:#{after.port} in #{Age.new(start)}: #{after.suffixes}")
        after
      end
    end
  end
end
