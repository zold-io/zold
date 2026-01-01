# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require 'futex'
require 'loog'
require_relative '../id'
require_relative '../verbose_thread'

# The sync entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # The entrance that makes sure only one thread works with a wallet
  class SyncEntrance
    def initialize(entrance, dir, timeout: 30, log: Loog::NULL)
      @entrance = entrance
      @dir = dir
      @timeout = timeout
      @log = log
    end

    def to_json
      @entrance.to_json
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      if File.exist?(@dir)
        FileUtils.rm_rf(@dir)
        @log.info("Directory #{@dir} deleted")
      end
      @entrance.start do
        yield(self)
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      Futex.new(File.join(@dir, id), log: @log, timeout: 60 * 60).open do
        @entrance.push(id, body)
      end
    end
  end
end
