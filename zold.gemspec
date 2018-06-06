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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'English'

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/zold/version'

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '2.2'
  s.required_ruby_version = '>= 2.2'
  s.name = 'zold'
  s.version = Zold::VERSION
  s.license = 'MIT'
  s.summary = 'ZOLD, a cryptocurrency'
  s.description = 'Non-blockchain cryptocurrency'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'http://github.com/zold-io/zold'
  s.files = `git ls-files`.split($RS)
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features|wp)/})
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_runtime_dependency 'concurrent-ruby', '~>1.0.5'
  s.add_runtime_dependency 'diffy', '~>3.2.0'
  s.add_runtime_dependency 'json', '~>1.8.6'
  s.add_runtime_dependency 'openssl', '~>2.1.1'
  s.add_runtime_dependency 'rainbow', '~>3.0'
  s.add_runtime_dependency 'rake', '12.3.1' # has to stay here for Heroku
  s.add_runtime_dependency 'rubocop', '0.52.0' # has to stay here for Heroku
  s.add_runtime_dependency 'rubocop-rspec' # has to stay here for Heroku
  s.add_runtime_dependency 'semantic', '~>1.6.1'
  s.add_runtime_dependency 'sinatra', '~>2.0.1'
  s.add_runtime_dependency 'slop', '~>4.4'
  s.add_runtime_dependency 'xcop', '~>0.5'
  s.add_development_dependency 'codecov', '0.1.10'
  s.add_development_dependency 'cucumber', '3.1.1'
  s.add_development_dependency 'minitest', '5.11.3'
  s.add_development_dependency 'rdoc', '4.2.0'
  s.add_development_dependency 'rspec-rails', '3.1.0'
  s.add_development_dependency 'webmock', '3.4.2'
end
