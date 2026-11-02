# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/host'
require_relative 'test__helper'

# Host test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestHost < Zold::Test
  def test_detects_loopback_hosts
    assert(
      %w[127.0.0.1 127.8.3.11 ::1 localhost LocalHost].all? { |h| Zold::Host.new(h).loopback? },
      'Loopback host was not detected'
    )
  end

  def test_accepts_public_hosts
    refute(
      %w[172.217.16.78 b2.zold.io 0.0.0.0].any? { |h| Zold::Host.new(h).loopback? },
      'Public host was treated as loopback'
    )
  end
end
