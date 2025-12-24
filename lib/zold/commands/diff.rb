# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'slop'
require 'diffy'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require 'loog'
require_relative '../patch'
require_relative '../wallet'

# DIFF command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # DIFF pulling command
  class Diff
    prepend ThreadBadge

    def initialize(wallets:, copies:, log: Loog::NULL)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold diff [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'At least one wallet ID is required' if mine.empty?
      stdout = ''
      mine.map { |i| Id.new(i) }.each do |id|
        stdout += diff(id, Copies.new(File.join(@copies, id)), opts)
      end
      stdout
    end

    private

    def diff(id, cps, _)
      raise "There are no remote copies, try 'zold fetch' first" if cps.all.empty?
      cps = cps.all.sort_by { |c| c[:score] }.reverse
      patch = Patch.new(@wallets, log: @log)
      cps.each do |c|
        patch.join(Wallet.new(c[:path]))
      end
      before = @wallets.acq(id) do |wallet|
        File.read(wallet.path)
      end
      after = ''
      Tempfile.open(['', Wallet::EXT]) do |f|
        patch.save(f.path, overwrite: true)
        after = File.read(f)
      end
      diff = Diffy::Diff.new(before, after, context: 0).to_s(:color)
      @log.info(diff)
      diff
    end
  end
end
