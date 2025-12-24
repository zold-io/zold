# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/zold/version'

Gem::Specification.new do |s|
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '>=2.5'
  s.name = 'zold'
  s.version = Zold::VERSION
  s.license = 'MIT'
  s.summary = 'A fast cryptocurrency for micro payments'
  s.description = "In the last few years digital currencies have successfully demonstrated \
their ability to become an alternative financial instrument in many \
different markets. Most of the technologies available at the moment are \
based on the principles of Blockchain architecture, including \
dominating currencies like Bitcoin and Ethereum. Despite its \
popularity, Blockchain is not the best possible solution for all scenarios. \
One such example is for fast micro-payments. \
Zold is an experimental alternative that enables distributed transactions between \
anonymous users, making micro-payments financially feasible. \
It borrows the proof-of-work principle from Bitcoin, \
and suggests a different architecture for digital wallet maintenance."
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'https://github.com/zold-io/zold'
  s.post_install_message = "Thanks for installing Zold #{Zold::VERSION}!
  Study our White Paper: https://papers.zold.io/wp.pdf
  Read our blog posts: https://blog.zold.io
  Try ZLD online wallet at: https://wts.zold.io
  Stay in touch with the community in Telegram: https://t.me/zold_io
  Follow us on Twitter: https://twitter.com/0crat
  If you have any issues, report to our GitHub repo: https://github.com/zold-io/zold"
  s.files = `git ls-files | grep -v -E '^(test/|\\.|renovate|fixtures/|features/|cucumber\\.yml)'`.split($RS)
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_dependency 'backtrace', '~>0.3'
  s.add_dependency 'concurrent-ruby', '~>1.1'
  s.add_dependency 'diffy', '~>3.3'
  s.add_dependency 'futex', '~>0.8'
  s.add_dependency 'get_process_mem', '~>0.2'
  s.add_dependency 'haml', '~>5.0'
  s.add_dependency 'json', '~>2.2'
  s.add_dependency 'loog', '>0'
  s.add_dependency 'memory_profiler', '~>1.0'
  s.add_dependency 'mimic', '~>0.4'
  s.add_dependency 'openssl', '>=1.0'
  s.add_dependency 'rainbow', '~>3.0'
  s.add_dependency 'semantic', '~>1.6'
  s.add_dependency 'sinatra', '~>3.0'
  s.add_dependency 'slop', '~>4.6'
  s.add_dependency 'sys-proctable', '~>1.2'
  s.add_dependency 'thin', '~>1.7'
  s.add_dependency 'threads', '~>0.3'
  s.add_dependency 'total', '~>0.3'
  s.add_dependency 'typhoeus', '~>1.3'
  s.add_dependency 'usagewatch_ext', '~>0.2'
  s.add_dependency 'zache', '~>0.12'
  s.add_dependency 'zold-score', '>0'
end
