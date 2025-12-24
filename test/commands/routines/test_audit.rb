# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../../lib/zold/commands/routines/audit'

# Audit test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestAudit < Zold::Test
  def test_audits
    FakeHome.new(log: fake_log).run do |home|
      opts = { 'routine-immediately' => true }
      routine = Zold::Routines::Audit.new(opts, home.wallets, log: fake_log)
      routine.exec
    end
  end
end
