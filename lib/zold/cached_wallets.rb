# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'zache'
require 'delegate'
require_relative 'endless'
require_relative 'thread_pool'

# Cached collection of wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
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
          sleep 5
          @zache.clean
        end
      end
      super
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
