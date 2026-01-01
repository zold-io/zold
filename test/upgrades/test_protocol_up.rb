# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../../upgrades/protocol_up'
require_relative '../fake_home'

# Protocol up.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestProtocolUp < Zold::Test
  def test_upgrades_protocol_in_wallet
    FakeHome.new(log: fake_log).run do |home|
      id = home.create_wallet.id
      Zold::ProtocolUp.new(home.dir, fake_log).exec
      home.wallets.acq(id) do |wallet|
        assert_equal(Zold::PROTOCOL, wallet.protocol)
      end
    end
  end
end
