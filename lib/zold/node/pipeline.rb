# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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

require 'tempfile'
require 'shellwords'
require_relative '../log'
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
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
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
        'ledger': File.exist?(@ledger) ? IO.read(@ledger).split("\n").count : 0
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
          Merge.new(wallets: wallets, remotes: @remotes, copies: copies.root, log: log).run(
            ['merge', id.to_s, "--ledger=#{Shellwords.escape(f.path)}"] +
            ["--trusted=#{Shellwords.escape(t.path)}", '--deep'] +
            ["--network=#{Shellwords.escape(@network)}"]
          )
        end
        @mutex.synchronize do
          txns = File.exist?(@ledger) ? IO.read(@ledger).strip.split("\n") : []
          txns += IO.read(f.path).strip.split("\n")
          IO.write(
            @ledger,
            txns.map { |t| t.split(';') }
              .uniq { |t| "#{t[1]}-#{t[3]}" }
              .reject { |t| Txn.parse_time(t[0]) < Time.now - 24 * 60 * 60 }
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
