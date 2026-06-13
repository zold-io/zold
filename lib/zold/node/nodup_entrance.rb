# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'openssl'
require 'loog'
require_relative '../size'
require_relative '../wallet'

# The entrance that ignores duplicates.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # The entrance that ignores dups
  class NoDupEntrance
    def initialize(entrance, wallets, log: Loog::NULL)
      @entrance = entrance
      @wallets = wallets
      @log = log
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      @entrance.start { yield(self) }
    end

    def to_json
      @entrance.to_json
    end

    # Returns a list of modified wallets (as Zold::Id)
    def push(id, body)
      before = @wallets.acq(id) { |w| w.exists? ? w.digest : '' }
      after = OpenSSL::Digest::SHA256.new(body).hexdigest
      if before == after
        @log.debug("Duplicate of #{id} ignored #{Size.new(body.length)}")
        return []
      end
      @log.debug("New content for #{id} arrived #{Size.new(body.length)}")
      @entrance.push(id, body)
    end
  end
end
