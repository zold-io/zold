# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/load'
require_relative 'test__helper'

# Load test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestLoad < Zold::Test
  def test_reads_load_average_on_freebsd
    assert_in_delta(
      3.47,
      Zold::Load.new(' 4:29PM  up 12 days,  3:02, 2 users, load averages: 3.47, 2.98, 2.87').value,
      0.001,
      'load average was not read from FreeBSD uptime output'
    )
  end

  def test_reads_load_average_on_linux
    assert_in_delta(
      0.52,
      Zold::Load.new(' 16:29:49 up 3 days,  2:01,  1 user,  load average: 0.52, 0.58, 0.59').value,
      0.001,
      'load average was not read from Linux uptime output'
    )
  end

  def test_reads_load_average_on_macos
    assert_in_delta(
      1.68,
      Zold::Load.new('16:29  up 2 days, 4:12, 3 users, load averages: 1.68 1.80 1.85').value,
      0.001,
      'load average was not read from macOS uptime output'
    )
  end

  def test_reads_comma_separated_load
    assert_in_delta(
      7.25,
      Zold::Load.new('16:29:49 up 3 days, 1 user, load average: 7,25, 6,58, 5,59').value,
      0.001,
      'load average with comma separator was not read'
    )
  end

  def test_reads_load_average_of_this_machine
    refute_predicate(Zold::Load.new.value, :negative?, 'load average of this machine was negative')
  end

  def test_fails_on_garbage
    assert_raises(Zold::Load::CantDetect) { Zold::Load.new('nothing useful here').value }
  end
end
