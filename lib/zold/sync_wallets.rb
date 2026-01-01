# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'futex'
require 'delegate'
require 'loog'

# Synchronized collection of wallets.
#
# This is a decorator for the Wallets class.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Synchronized collection of wallets
  class SyncWallets < SimpleDelegator
    def initialize(wallets, log: Loog::NULL, dir: wallets.path)
      @wallets = wallets
      @log = log
      @dir = dir
      super(wallets)
    end

    def acq(id, exclusive: false)
      @wallets.acq(id, exclusive: exclusive) do |wallet|
        Futex.new(wallet.path, log: @log, lock: File.join(@dir, "#{id}.lock")).open(exclusive) do
          yield wallet
        end
      end
    end
  end
end
