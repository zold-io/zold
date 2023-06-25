# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy, Inc.
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

require 'tmpdir'
require 'slop'
require 'English'
require_relative '../../lib/zold'

Before do
  @cwd = Dir.pwd
  @dir = Dir.mktmpdir('test')
  FileUtils.copy('fixtures/id_rsa', @dir)
  FileUtils.copy('fixtures/id_rsa.pub', @dir)
  FileUtils.mkdir_p(@dir) unless File.exist?(@dir)
  Dir.chdir(@dir)
end

After do
  Dir.chdir(@cwd)
  FileUtils.rm_rf(@dir) if File.exist?(@dir)
end

When(%r{^I run ([a-z/-]+) with "([^"]*)"$}) do |cmd, args|
  home = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
  @stdout = `ruby -I#{home}/lib #{home}/#{cmd} #{args} 2>&1`
  @exitstatus = $CHILD_STATUS.exitstatus
end

When(/^I run bash with:$/) do |text|
  FileUtils.copy_entry(@cwd, File.join(@dir, 'zold'))
  IO.write('run.sh', text)
  @stdout = `/bin/bash run.sh 2>&1`
  @exitstatus = $CHILD_STATUS.exitstatus
end

When(/^I have "([^"]*)" file with content:$/) do |file, text|
  FileUtils.mkdir_p(File.dirname(file)) unless File.exist?(file)
  File.open(file, 'w:ASCII-8BIT') do |f|
    f.write(text.gsub(/\\xFF/, 0xFF.chr))
  end
end

Then(/^Stdout contains "([^"]*)"$/) do |txt|
  raise "STDOUT doesn't contain '#{txt}':\n#{@stdout}" unless @stdout.include?(txt)
end

Then(/^Stdout is empty$/) do
  raise "STDOUT is not empty:\n#{@stdout}" unless @stdout == ''
end

Then(/^Exit code is zero$/) do
  raise "Non-zero exit #{@exitstatus}:\n#{@stdout}" unless @exitstatus.zero?
end

Then(/^Exit code is not zero$/) do
  raise 'Zero exit code' if @exitstatus.zero?
end

Given(/^It is Unix$/) do
  pending if Gem.win_platform?
end

Given(/^It is Windows$/) do
  pending unless Gem.win_platform?
end
