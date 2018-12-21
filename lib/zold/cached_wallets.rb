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

require 'zache'
require 'delegate'
require_relative 'endless'
require_relative 'thread_pool'

# Cached collection of wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Collection of local wallets
  class CachedWallets < SimpleDelegator
    def initialize(wallets)
      @wallets = wallets
      @zache = Zache.new
      @clean = ThreadPool.new('cached-wallets')
      @clean.add do
        Endless.new('cached_wallets').run do
          sleep 1
          @zache.clean
          puts "+++ cached wallets: #{ObjectSpace.memsize_of(@zache)}"
        end
      end
      super(wallets)
    end

    def acq(id, exclusive: false)
      @wallets.acq(id, exclusive: exclusive) do |wallet|
        c = @zache.get(id.to_s, lifetime: 15) { wallet }
        res = yield c
        c.flush if exclusive
        res
      end
    end
  end
end
