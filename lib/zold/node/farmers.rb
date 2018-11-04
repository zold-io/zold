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
    # Plain and simple
    class Plain
      def up(score)
        score.next
      end
    end

    # In a child process
    class Spawn
      def initialize(log: Log::Quiet.new)
        @log = log
      end

      def up(score)
        start = Time.now
        bin = File.expand_path(File.join(File.dirname(__FILE__), '../../../bin/zold'))
        raise "Zold binary not found at #{bin}" unless File.exist?(bin)
        cmd = [
          'ruby',
          Shellwords.escape(bin),
          '--skip-upgrades',
          Shellwords.escape("--info-thread=#{Thread.current.name}"),
          Shellwords.escape("--info-start=#{Time.now.utc.iso8601}"),
          '--low-priority',
          'next',
          Shellwords.escape(score)
        ].join(' ')
        Open3.popen2e(cmd) do |stdin, stdout, thr|
          Thread.current.thread_variable_set(:pid, thr.pid.to_s)
          @log.debug("Scoring started in proc ##{thr.pid} \
for #{score.value}/#{score.strength} at #{score.host}:#{score.port}")
          begin
            stdin.close
            buffer = +''
            loop do
              begin
                buffer << stdout.read_nonblock(1024)
                # rubocop:disable Lint/HandleExceptions
              rescue IO::WaitReadable => _
                # rubocop:enable Lint/HandleExceptions
                # nothing to do here
              rescue StandardError => e
                @log.error(buffer)
                raise e
              end
              break if buffer.end_with?("\n") && thr.value.to_i.zero?
              if stdout.closed?
                raise "Failed to calculate the score (##{thr.value}): #{buffer}" unless thr.value.to_i.zero?
                break
              end
              sleep 0.25
              Thread.current.thread_variable_set(:buffer, buffer.length.to_s)
            end
            after = Score.parse(buffer.strip)
            @log.debug("Next score #{after.value}/#{after.strength} found in proc ##{thr.pid} \
for #{after.host}:#{after.port} in #{Age.new(start)}: #{after.suffixes}")
            after
          ensure
            kill(thr.pid)
          end
        end
      end

      private

      def kill(pid)
        Process.kill('TERM', pid)
        @log.debug("Process ##{pid} killed")
      rescue StandardError => e
        @log.debug("No need to kill process ##{pid} since it's dead already: #{e.message}")
      end
    end
  end
end
