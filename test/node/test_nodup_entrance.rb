# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/nodup_entrance'
require_relative 'fake_entrance'

# NoDupEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestNoDupEntrance < Zold::Test
  def test_ignores_dup
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      Zold::NoDupEntrance.new(RealEntrance.new, home.wallets, log: fake_log).start do |e|
        assert(e.push(wallet.id, File.read(wallet.path)).empty?)
      end
    end
  end

  class RealEntrance < FakeEntrance
    def push(id, _)
      [id]
    end
  end
end
