# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'open3'
require 'English'
require_relative 'test__helper'
require_relative '../lib/zold/version'
require_relative '../lib/zold/age'

# Zold main module test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestZold < Zold::Test
  Dir.new('fixtures/scripts').select { |f| f =~ /\.sh$/ && !f.start_with?('_') }.each do |f|
    method = "test_#{f.gsub(/\.sh$/, '').gsub(/[^a-z]/, '_')}"
    define_method(method) do
      start = Time.now
      fake_log.info("\n\n#{method} running (script at #{f})...")
      Dir.mktmpdir do |dir|
        FileUtils.cp('fixtures/id_rsa.pub', dir)
        FileUtils.cp('fixtures/id_rsa', dir)
        script = File.join(dir, f)
        File.write(script, File.read('fixtures/scripts/_head.sh') + File.read(File.join('fixtures/scripts', f)))
        bin = File.join(Dir.pwd, 'bin/zold')
        out = []
        Dir.chdir(dir) do
          Open3.popen2e("/bin/bash #{f} #{bin} 2>&1") do |stdin, stdout, thr|
            stdin.close
            until stdout.eof?
              line = stdout.gets
              fake_log.info(line)
              out << line
            end
            code = thr.value.to_i
            assert_equal(0, code, "#{f}\n#{out.join}")
          end
        end
        sleep 1 # It's a workaround, I can't fix the bug (tests crash sporadically)
      end
      fake_log.info("\n\n#{f} done in #{Zold::Age.new(start)}")
    end
  end

  def test_help
    stdout = exec('--help')
    assert(stdout.include?('Usage: zold'))
  end

  def test_show_version
    stdout = exec('--version')
    assert(stdout.include?(Zold::VERSION))
  end

  def test_create_new_wallet
    Dir.mktmpdir do |dir|
      FileUtils.cp('fixtures/id_rsa.pub', dir)
      FileUtils.cp('fixtures/id_rsa', dir)
      stdout = exec(
        '--verbose --trace create --public-key=id_rsa.pub',
        dir
      )
      assert(stdout.include?('created at'))
    end
  end

  private

  def exec(tail, dir = Dir.pwd)
    bin = File.expand_path(File.join(Dir.pwd, 'bin/zold'))
    stdout = `cd #{dir} && #{bin} #{tail} 2>&1`
    unless $CHILD_STATUS.exitstatus.zero?
      puts stdout
      assert_equal($CHILD_STATUS.exitstatus, 0)
    end
    stdout
  end
end
