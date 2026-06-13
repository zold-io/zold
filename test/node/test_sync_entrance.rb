# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/node/sync_entrance'
require_relative 'fake_entrance'

# SyncEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestSyncEntrance < Zold::Test
  def test_renders_json
    FakeHome.new(log: fake_log).run do |home|
      Zold::SyncEntrance.new(FakeEntrance.new, File.join(home.dir, 'x'), log: fake_log).start do |e|
        refute_nil(e.to_json)
      end
    end
  end
end
