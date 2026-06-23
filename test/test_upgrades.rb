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
  # @todo #327:30min Uncomment, when you're ready to work on upgrade manager's
  #  test case of absent version file. Start with running the test first.
  def test_no_version_file_is_ok
    skip('the absent-version-file case is not implemented yet')
    Dir.mktmpdir do |dir|
      version = '0.0.1'
      script(dir, version)
      assert_output(/#{expected(version)}/) do
        upgrade(dir)
      end
    end
  end

  # @todo #327:30min Uncomment, when you're ready to work on upgrade manager's
  #  test case of running only pending upgrade scripts (i.e. the scripts with
  #  versions greater than those in the version file).
  def test_pending_scripts_run
    skip('pending upgrade scripts are not implemented yet')
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
