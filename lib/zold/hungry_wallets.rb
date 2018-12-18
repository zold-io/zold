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

require 'delegate'
require_relative 'log'
require_relative 'thread_pool'
require_relative 'commands/pull'

# Wallets that PULL what's missing, in the background.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Wallets decorator that adds missing wallets to the queue to be pulled later.
  class HungryWallets < SimpleDelegator
    def initialize(wallets, remotes, copies, pool,
      log: Log::NULL, network: 'test')
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
      @network = network
      @pool = pool
      @queue = Queue.new
      @pool.add do
        Endless.new('hungry', log: log).run do
          id = @queue.pop
          Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
            ['pull', id.to_s, "--network=#{@network}"]
          )
        rescue Pull::EdgesOnly => e
          @log.error("Can't hungry-pull #{id}: #{e.message}")
        end
      end
      super(wallets)
    end

    def acq(id, exclusive: false)
      @wallets.acq(id, exclusive: exclusive) do |wallet|
        unless wallet.exists?
          if @queue.size > 256
            @log.error("Hungry queue is full with #{@queue.size} wallets, can't add #{id}")
          else
            @queue << id
          end
        end
        yield wallet
      end
    end
  end
end
