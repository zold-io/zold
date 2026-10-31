# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/upgrades'
require_relative '../lib/zold/version_file'
require_relative 'test__helper'

# Upgrade test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestUpgrades < Zold::Test
  def test_no_version_file_is_ok
    Dir.mktmpdir do |dir|
      version = '0.0.1'
      script(dir, version)
      assert_output(/#{expected(version)}/) do
        upgrade(dir)
      end
    end
  end

  def test_pending_scripts_run
    Dir.mktmpdir do |dir|
      %w[1 2].each do |version|
        script(dir, version)
      end
      seed(dir, '1')
      assert_output(/#{expected('2')}/) do
        upgrade(dir)
      end
    end
  end

  def test_already_ran_scripts_dont_run
    Dir.mktmpdir do |dir|
      %w[1 2].each do |version|
        script(dir, version)
      end
      seed(dir, '1')
      out, _err =
        capture_io do
        upgrade(dir)
      end
      refute_match(/#{expected('1')}/, out)
    end
  end

  private

  def upgrade(dir)
    Zold::Upgrades.new(vfile(dir), dir, { network: 'test' }).run
  end

  def vfile(dir)
    Zold::VersionFile.new(File.join(dir, 'version'))
  end

  def seed(dir, version)
    File.write(File.join(dir, 'version'), version)
  end

  def script(dir, version)
    File.write(File.join(dir, "#{version}.rb"), "puts \"#{expected(version)}\"")
  end

  def expected(version)
    "upgrading to #{version}"
  end
end
