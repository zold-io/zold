# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'delegate'
require 'zache'
require 'shellwords'
require 'loog'
require_relative 'thread_pool'
require_relative 'commands/pull'
require_relative 'commands/fetch'

# Wallets that PULL what's missing, in the background.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Wallets decorator that adds missing wallets to the queue to be pulled later.
  class HungryWallets < SimpleDelegator
    def initialize(wallets, remotes, copies, pool,
      log: Loog::NULL, network: 'test')
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
      @network = network
      @pool = pool
      @queue = []
      @mutex = Mutex.new
      @missed = Zache.new
      @pool.add do
        Endless.new('hungry', log: log).run { pull }
      end
      super(wallets)
    end

    def acq(id, exclusive: false)
      @wallets.acq(id, exclusive: exclusive) do |wallet|
        unless wallet.exists?
          if @queue.size > 256
            @log.error("Hungry queue is full with #{@queue.size} wallets, can't add #{id}")
          elsif @missed.exists?(id.to_s)
            @log.debug("Hungry queue has seen #{id} just #{Age.new(@missed.mtime(id.to_s))} ago \
(among #{@missed.size} others) and it was not found")
          else
            @mutex.synchronize do
              unless @queue.include?(id)
                @missed.put(id.to_s, true, lifetime: 5 * 60)
                @queue << id
                @log.debug("Hungry queue got #{id}, at the pos no.#{@queue.size - 1}")
              end
            end
          end
        end
        yield wallet
      end
    end

    private

    def pull
      id = @mutex.synchronize { @queue.pop }
      if id.nil?
        sleep 0.2
        return
      end
      if @remotes.all.empty?
        @log.debug("Can't hungry-pull #{id}, the list of remotes is empty")
        return
      end
      begin
        Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
          ['pull', id.to_s, "--network=#{Shellwords.escape(@network)}", '--tolerate-edges', '--tolerate-quorum=1']
        )
        @missed.remove(id.to_s)
      rescue Fetch::Error => e
        @log.error("Can't hungry-pull #{id}: #{e.message}")
      end
    end
  end
end
