# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require_relative '../../../lib/zold/commands/routines/retire'
require_relative '../../../lib/zold/remotes'
require_relative '../../test__helper'

# Retire test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestRetire < Zold::Test
  def test_retires
    Zold::Routines::Retire.new(
      { 'never-reboot' => false, 'routine-immediately' => true },
      log: fake_log
    ).exec(10 * 24 * 60)
  end
end
