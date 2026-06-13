# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../../lib/zold/remotes'
require_relative '../../../lib/zold/commands/routines/retire'

# Retire test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestRetire < Zold::Test
  def test_retires
    opts = { 'never-reboot' => false, 'routine-immediately' => true }
    routine = Zold::Routines::Retire.new(opts, log: fake_log)
    routine.exec(10 * 24 * 60)
  end
end
