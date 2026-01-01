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
  # @todo #327:30min Uncomment, when you're ready to work on upgrade manager's
  #  test case of absent version file. Start with running the test first.
  def test_no_version_file_is_ok
    skip
    Dir.mktmpdir do |dir|
      script_version = '0.0.1'
      create_upgrade_file(dir, script_version)
      assert_output(/#{expected_upgrade_script_output(script_version)}/) do
        run_upgrades(dir)
      end
    end
  end

  # @todo #327:30min Uncomment, when you're ready to work on upgrade manager's
  #  test case of running only pending upgrade scripts (i.e. the scripts with
  #  versions greater than those in the version file).
  def test_pending_scripts_run
    skip
    Dir.mktmpdir do |dir|
      %w[1 2].each do |script_version|
        create_upgrade_file(dir, script_version)
      end
      create_version_file(dir, '1')
      assert_output(/#{expected_upgrade_script_output('2')}/) do
        run_upgrades(dir)
      end
    end
  end

  def test_already_ran_scripts_dont_run
    Dir.mktmpdir do |dir|
      %w[1 2].each do |script_version|
        create_upgrade_file(dir, script_version)
      end
      create_version_file(dir, '1')
      out, _err = capture_io do
        run_upgrades(dir)
      end
      refute_match(/#{expected_upgrade_script_output('1')}/, out)
    end
  end

  private

  def run_upgrades(dir)
    Zold::Upgrades.new(version_file(dir), dir, { network: 'test' }).run
  end

  def version_file(dir)
    Zold::VersionFile.new(File.join(dir, 'version'))
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
