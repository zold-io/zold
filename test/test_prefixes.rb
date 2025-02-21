# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/prefixes'

# Prefixes test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestPrefixes < Zold::Test
  def test_creates_and_validates
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      prefixes = Zold::Prefixes.new(wallet)
      (8..32).each do |len|
        50.times do
          prefix = prefixes.create(len)
          assert_equal(len, prefix.length)
          assert(wallet.prefix?(prefix), "Prefix '#{prefix}' not found")
        end
      end
    end
  end
end
