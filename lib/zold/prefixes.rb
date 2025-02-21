# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'key'

# Payment prefixes.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Payment prefixes
  class Prefixes
    def initialize(wallet)
      @wallet = wallet
    end

    def create(length = 8)
      raise "Length #{length} is too small" if length < 8
      raise "Length #{length} is too big" if length > 32
      key = @wallet.key.to_pub
      prefix = ''
      rnd = Random.new
      until prefix =~ /^[a-zA-Z0-9]+$/
        start = rnd.rand(key.length - length)
        prefix = key[start..(start + length - 1)]
      end
      prefix
    end
  end
end
