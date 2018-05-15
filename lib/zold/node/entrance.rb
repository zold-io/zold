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
require_relative '../log'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'

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
    end

    def push(id, body)
      @semaphores.put_if_absent(id, Mutex.new)
      @semaphores.get(id).synchronize do
        push_unsafe(id, body)
      end
    end

    def push_unsafe(id, body)
      copies = Copies.new(File.join(@copies, id.to_s))
      copies.add(body, 'remote', Remotes::PORT, 0)
      Fetch.new(
        remotes: @remotes, copies: copies.root, log: @log
      ).run([id.to_s, "--ignore-node=#{@address}"])
      modified = Merge.new(
        wallets: @wallets, copies: copies.root, log: @log
      ).run([id.to_s])
      debt = Tax.new(@wallets.find(id)).debt
      if debt > Tax::TRIAL
        raise "Taxes are not paid, the debt is #{debt} (#{debt.to_i} zents), won't promote the wallet"
      end
      copies.remove('remote', Remotes::PORT)
      modified.each do |m|
        Push.new(
          wallets: @wallets, remotes: @remotes, log: @log
        ).run([m.to_s])
      end
      modified
    end
  end
end
