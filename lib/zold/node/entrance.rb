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

require 'concurrent'
require 'tempfile'
require_relative 'emission'
require_relative '../log'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'
require_relative '../commands/clean'

# The entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class Entrance
    def initialize(wallets, remotes, copies, address, log: Log::Quiet.new)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @address = address
      @log = log
      @semaphores = Concurrent::Map.new
      @pool = Concurrent::FixedThreadPool.new(16)
    end

    def push(id, body, sync: true)
      check(body)
      if sync
        push_sync(id, body)
      else
        @pool.post do
          push_sync(id, body)
        end
      end
    end

    def check(body)
      Tempfile.open do |f|
        File.write(f.path, body)
        wallet = Wallet.new(f)
        break unless wallet.network == Wallet::MAIN_NETWORK
        balance = wallet.balance
        if balance.negative? && !wallet.root?
          raise "The balance #{balance} of #{wallet.id} is negative and it's not a root wallet"
        end
        Emission.new(wallet).check
        tax = Tax.new(wallet)
        if tax.in_debt?
          raise "Taxes are not paid, can't accept the wallet; the debt is #{tax.debt} (#{tax.debt.to_i} zents)"
        end
      end
    end

    def push_sync(id, body)
      @semaphores.put_if_absent(id, Mutex.new)
      @semaphores.get(id).synchronize do
        modified = push_unsafe(id, body)
        @log.info("Accepted #{id} and modified: #{modified.join(', ')}")
        modified
      end
    end

    def push_unsafe(id, body)
      copies = Copies.new(File.join(@copies, id.to_s))
      copies.add(body, '0.0.0.0', Remotes::PORT, 0)
      Fetch.new(
        wallets: @wallets, remotes: @remotes, copies: copies.root, log: @log
      ).run(['fetch', id.to_s, "--ignore-node=#{@address}"])
      modified = Merge.new(
        wallets: @wallets, copies: copies.root, log: @log
      ).run(['merge', id.to_s])
      Clean.new(wallets: @wallets, copies: copies.root, log: @log).run(['clean', id.to_s])
      copies.remove('remote', Remotes::PORT)
      Push.new(
        wallets: @wallets, remotes: @remotes, log: @log
      ).run(['push', "--ignore-node=#{@address}"] + modified.map(&:to_s))
      modified
    end
  end
end
