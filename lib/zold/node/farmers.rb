# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'backtrace'
require 'zold/score'
require 'shellwords'
require_relative '../log'
require_relative '../age'

# Farmers.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
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

    # In a child process
    class Spawn
      def initialize(log: Log::NULL)
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
          "--info-tid=#{Shellwords.escape(Thread.current.thread_variable_get(:tid))}",
          "--info-thread=#{Shellwords.escape(Thread.current.name)}",
          "--info-start=#{Shellwords.escape(Time.now.utc.iso8601)}",
          '--low-priority',
          'next',
          Shellwords.escape(score)
        ].join(' ')
        Open3.popen2e(cmd) do |stdin, stdout, thr|
          Thread.current.thread_variable_set(:pid, thr.pid.to_s)
          at_exit { Farmers.kill(@log, thr.pid, start) }
          @log.debug("Scoring started in proc ##{thr.pid} \
for #{score.value}/#{score.strength} at #{score.host}:#{score.port}")
          begin
            stdin.close
            buffer = +''
            loop do
              begin
                buffer << stdout.read_nonblock(16 * 1024)
              rescue IO::WaitReadable
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
              sleep(1)
              Thread.current.thread_variable_set(:buffer, buffer.length.to_s)
            end
            after = Score.parse(buffer.strip)
            @log.debug("Next score #{after.value}/#{after.strength} found in proc ##{thr.pid} \
for #{after.host}:#{after.port} in #{Age.new(start)}: #{after.suffixes}")
            after
          ensure
            Farmers.kill(@log, thr.pid, start)
          end
        end
      end
    end
  end
end
