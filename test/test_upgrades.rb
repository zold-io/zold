# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require_relative 'test__helper'
require_relative '../lib/zold/upgrades'
require_relative '../lib/zold/version_file'

# Upgrade test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestUpgrades < Minitest::Test
  def test_no_version_file_is_ok
    skip
    Dir.mktmpdir do |dir|
      script_version = '0.0.1'
      create_upgrade_file(dir, script_version)
      expected_output = expected_upgrade_script_output(script_version)
      assert_output(/#{expected_output}/) do
        run_upgrades(dir)
      end
    end
  end

  def test_pending_scripts_run
    skip
    Dir.mktmpdir do |dir|
      %w[0.0.1 0.0.2].each do |script_version|
        create_upgrade_file(dir, script_version)
      end
      create_version_file(dir, '0.0.1')
      expected_output = expected_upgrade_script_output('0.0.2')
      assert_output(/#{expected_output}/) do
        run_upgrades(dir)
      end
    end
  end

  def test_already_ran_scripts_dont_run
    Dir.mktmpdir do |dir|
      %w[0.0.1 0.0.2].each do |script_version|
        create_upgrade_file(dir, script_version)
      end
      create_version_file(dir, '0.0.1')
      must_not_be_in_output = expected_upgrade_script_output('0.0.1')
      out, _err = capture_io do
        run_upgrades(dir)
      end
      refute_match(/#{must_not_be_in_output}/, out)
    end
  end

  private

  def run_upgrades(dir)
    Zold::Upgrades.new(version_file(dir), dir).run
  end

  def version_file(dir)
    Zold::VersionFile.new(File.join(dir, 'version'))
  end

  def create_version_file(dir, version)
    IO.write(File.join(dir, 'version'), version)
  end

  def create_upgrade_file(dir, version)
    upgrade_file_name = File.join(dir, "#{version}.rb")
    IO.write(upgrade_file_name,
             "puts \"#{expected_upgrade_script_output(version)}\"")
  end

  def expected_upgrade_script_output(version)
    "upgrading to #{version}"
  end
end
