# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'slop'
require 'zold/score'
require_relative 'thread_badge'
require 'loog'

# SCORE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Calculate score
  class Calculate
    prepend ThreadBadge

    def initialize(log: Loog::NULL)
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold score [options]
Available options:"
        o.string '--time',
          'The time to start a score prefix with (default: current time)',
          default: Time.now.utc.iso8601
        o.string '--invoice',
          'The invoice you want to collect money to'
        o.integer '--port',
          "TCP port to open for the Net (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.string '--host', 'Host name (default: 127.0.0.1)',
          default: '127.0.0.1'
        o.integer '--strength',
          "The strength of the score (default: #{Score::STRENGTH})",
          default: Score::STRENGTH
        o.integer '--max',
          'Maximum value to find and then stop (default: 8)',
          default: 8
        o.bool '--hide-hash', 'Don\'t print hash',
          default: false
        o.bool '--hide-time', 'Don\'t print calculation time per each score',
          default: false
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      calculate(opts)
    end

    private

    def calculate(opts)
      start = Time.now
      mstart = Time.now
      strength = opts[:strength]
      raise "Invalid strength: #{strength}" if strength <= 0 || strength > 8
      score = Zold::Score.new(
        time: Txn.parse_time(opts[:time]), host: opts[:host], port: opts[:port].to_i,
        invoice: opts[:invoice], strength: strength
      )
      loop do
        msg = score.to_s
        msg += (score.value.positive? ? " #{score.hash}" : '') unless opts['hide-hash']
        msg += " #{(Time.now - mstart).round(2)}s" unless opts['hide-time']
        @log.info(msg)
        break if score.value >= opts[:max].to_i
        mstart = Time.now
        score = score.next
      end
      seconds = (Time.now - start).round(2)
      @log.info("Took #{seconds} seconds, #{seconds / score.value} per value")
      score
    end
  end
end
