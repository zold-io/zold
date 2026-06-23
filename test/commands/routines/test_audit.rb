# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require_relative '../../../lib/zold/commands/routines/audit'
require_relative '../../test__helper'

# Audit test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestAudit < Zold::Test
  def test_audits
    FakeHome.new(log: fake_log).run do |home|
      Zold::Routines::Audit.new({ 'routine-immediately' => true }, home.wallets, log: fake_log).exec
    end
  end
end
