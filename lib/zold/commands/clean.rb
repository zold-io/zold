# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'futex'
require 'json'
require 'rainbow'
require 'slop'
require 'time'
require 'uri'
require 'zold/score'
require_relative '../age'
require_relative '../size'
require_relative 'args'
require 'loog'
require_relative '../copies'
require_relative '../hands'
require_relative '../http'
require_relative '../thread_pool'

# CLEAN command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # CLEAN command
  class Clean
    def initialize(wallets:, copies:, log: Loog::NULL)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts =
        Slop.parse(args, help: true, suppress_errors: true) do |o|
          o.banner = <<~BANNER
            Usage: zold clean [ID...] [options]
            Available options:
          BANNER
          o.integer('--threads', 'How many threads to use for cleaning copies (default: 1)', default: 1)
          o.integer('--max-age', 'Maximum age for a copy to stay, in hours (default: 24)', default: 24)
          o.bool('--help', 'Print instructions')
        end
      mine = Args.new(opts, @log).take || return
      list = mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }
      Hands.exec(opts['threads'], list.uniq) do |id|
        clean(Copies.new(File.join(@copies, id), log: @log), opts)
      end
    end

    def clean(cps, opts)
      # rubocop:disable Elegant/NoRedundantVariable
      start = Time.now
      deleted = cps.clean(max: opts['max-age'] * 60 * 60)
      # rubocop:enable Elegant/NoRedundantVariable
      list =
        cps.all.map do |c|
          "#{c[:name]}: #{c[:score]} #{c[:total]}n #{Wallet.new(c[:path]).mnemo} " \
            "#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}#{' master' if c[:master]}"
        end
      @log.debug(
        "#{deleted} expired local copies removed for #{cps} " \
        "in #{Age.new(start, limit: 0.01)}," \
        "#{list.empty? ? 'nothing left' : "#{list.count} left:\n#{list.join("\n")}"}"
      )
    end
  end
end
