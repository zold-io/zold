# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/zold/upgrades'
require_relative '../lib/zold/version_file'

# Upgrade test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestUpgrades < Zold::Test
  def test_no_version_file_is_ok
    Dir.mktmpdir do |dir|
      script_version = '0.0.1'
      create_upgrade_file(dir, script_version)
      assert_output(/#{expected_upgrade_script_output(script_version)}/) do
        run_upgrades(dir)
      end
    end
  end

  def test_pending_scripts_run
    Dir.mktmpdir do |dir|
      %w[1 2].each do |script_version|
        create_upgrade_file(dir, "0.0.#{script_version}")
      end
      create_version_file(dir, '0.0.1')
      assert_output(/#{expected_upgrade_script_output('0.0.2')}/) do
        run_upgrades(dir)
      end
    end
  end

  def test_already_ran_scripts_dont_run
    Dir.mktmpdir do |dir|
      %w[1 2].each do |script_version|
        create_upgrade_file(dir, "0.0.#{script_version}")
      end
      create_version_file(dir, '0.0.1')
      out, _err = capture_io do
        run_upgrades(dir)
      end
      refute_match(/#{expected_upgrade_script_output('0.0.1')}/, out)
    end
  end

  private

  def run_upgrades(dir)
    Zold::Upgrades.new(version_file(dir), dir, { network: 'test' }).run
  end

  def version_file(dir)
    Zold::VersionFile.new(dir)
  end

  def create_version_file(dir, version)
    File.write(File.join(dir, 'version'), version)
  end

  def create_upgrade_file(dir, version)
    File.write(
      File.join(dir, "#{version}.rb"),
      "puts \"#{expected_upgrade_script_output(version)}\""
    )
  end

  def expected_upgrade_script_output(version)
    "upgrading to #{version}"
  end
end
