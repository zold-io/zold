# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'openssl'
require 'zache'
require_relative '../log'
require_relative '../size'
require_relative '../age'

# The entrance that ignores something we've seen already.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # The no-spam entrance
  class NoSpamEntrance
    def initialize(entrance, period: 60 * 60, log: Log::NULL)
      @entrance = entrance
      @log = log
      @period = period
      @zache = Zache.new
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      @entrance.start { yield(self) }
    end

    def to_json
      @entrance.to_json
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      before = @zache.get(id.to_s, lifetime: @period) { '' }
      after = hash(id, body)
      if before == after
        @log.debug("Spam of #{id} ignored; the wallet content of #{Size.new(body.length)} \
and '#{after[0..8]}' hash has already been seen #{Age.new(@zache.mtime(id.to_s))} ago")
        return []
      end
      @zache.put(id.to_s, after)
      @entrance.push(id, body)
    end

    private

    def hash(id, body)
      OpenSSL::Digest.new('SHA256', "#{id} #{body}").hexdigest
    end
  end
end
