# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../../lib/zold/node/trace'

class TraceTest < Zold::Test
  def test_records_log_lines
    trace = Zold::Trace.new(fake_log, 2)
    trace.error('This should not be visible')
    trace.error('How are you, друг?')
    trace.error('Works?')
    refute_includes(trace.to_s, 'visible')
    assert_includes(trace.to_s, 'друг')
  end
end
