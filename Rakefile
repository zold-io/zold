# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require 'rake'
require 'date'
require 'rdoc'
require 'rake/clean'

def name
  @name ||= File.basename(Dir['*.gemspec'].first, '.*')
end

def version
  Gem::Specification.load(Dir['*.gemspec'].first).version
end

task default: %i[clean test features rubocop yard xcop copyright]

require 'rake/testtask'
desc 'Run all unit tests'
Rake::TestTask.new(:test) do |test|
  ENV['TEST_QUIET_LOG'] = 'true' if ARGV.include?('--quiet')
  Rake::Cleaner.cleanup_files(['coverage'])
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
  test.warning = false
end

require 'rubocop/rake_task'
desc 'Run RuboCop on all directories'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
  task.requires << 'rubocop-rspec'
end

require 'yard'
desc 'Build Yard documentation'
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features --format pretty'
  Rake::Cleaner.cleanup_files(['coverage'])
end
Cucumber::Rake::Task.new(:'features:html') do |t|
  t.profile = 'html_report'
end

require 'xcop/rake_task'
desc 'Validate all XML/XSL/XSD/HTML files for formatting'
Xcop::RakeTask.new :xcop do |task|
  task.license = 'LICENSE.txt'
  task.includes = ['**/*.xml', '**/*.xsl', '**/*.xsd', '**/*.html']
  task.excludes = ['target/**/*', 'coverage/**/*', 'wp/**/*', '.yardoc/**/*', 'doc/**/*']
end

task :copyright do
  sh "grep -q -r '2018-#{Date.today.strftime('%Y')}' \
    --include '*.rb' \
    --include '*.txt' \
    --include 'Rakefile' \
    ."
end
