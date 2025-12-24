# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'shellwords'
require 'loog'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../age'
require_relative '../commands/clean'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'

# The pipeline that accepts new wallets and merges them.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # The pipeline
  class Pipeline
    def initialize(remotes, copies, address, ledger: '/dev/null', network: 'test')
      @remotes = remotes
      @copies = copies
      @address = address
      @network = network
      @history = []
      @speed = []
      @mutex = Mutex.new
      @ledger = ledger
    end

    # Show its internals.
    def to_json
      {
        ledger: File.exist?(@ledger) ? File.read(@ledger).split("\n").count : 0
      }
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body, wallets, log)
      start = Time.now
      copies = Copies.new(File.join(@copies, id.to_s))
      host = '0.0.0.0'
      copies.add(body, host, Remotes::PORT, 0)
      unless @remotes.all.empty?
        Fetch.new(
          wallets: wallets, remotes: @remotes, copies: copies.root, log: log
        ).run(['fetch', id.to_s, "--ignore-node=#{@address}", "--network=#{@network}", '--quiet-if-absent'])
      end
      modified = merge(id, copies, wallets, log)
      Clean.new(wallets: wallets, copies: copies.root, log: log).run(
        ['clean', id.to_s, '--max-age=1']
      )
      copies.remove(host, Remotes::PORT)
      if modified.empty?
        log.info("Accepted #{id} in #{Age.new(start, limit: 1)} and not modified anything")
      else
        log.info("Accepted #{id} in #{Age.new(start, limit: 1)} and modified #{modified.join(', ')}")
      end
      modified << id if copies.all.count > 1
      modified
    end

    private

    def merge(id, copies, wallets, log)
      Tempfile.open do |f|
        modified = Tempfile.open do |t|
          host, port = @address.split(':')
          Merge.new(wallets: wallets, remotes: @remotes, copies: copies.root, log: log).run(
            ['merge', id.to_s, "--ledger=#{Shellwords.escape(f.path)}"] +
            ["--trusted=#{Shellwords.escape(t.path)}"] +
            ["--network=#{Shellwords.escape(@network)}"] +
            (@remotes.master?(host, port.to_i) ? ['--no-baseline', '--depth=4'] : [])
          )
        end
        @mutex.synchronize do
          txns = File.exist?(@ledger) ? File.read(@ledger).strip.split("\n") : []
          txns += File.read(f.path).strip.split("\n")
          File.write(
            @ledger,
            txns.map { |t| t.split(';') }
              .uniq { |t| "#{t[1]}-#{t[3]}" }
              .reject { |t| Txn.parse_time(t[0]) < Time.now - (24 * 60 * 60) }
              .map { |t| t.join(';') }
              .join("\n")
              .strip
          )
        end
        modified
      end
    end
  end
end
