# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT
Feature: Gem Package
  As a source code writer I want to be able to
  package the Gem into .gem file

  Scenario: Gem can be packaged
    Given It is Unix
    Given I have "execs.rb" file with content:
    """
    #!/usr/bin/env ruby
    require 'rubygems'
    spec = Gem::Specification::load('./spec.rb')
    if spec.executables.empty?
      fail 'no executables: ' + IO.read('./spec.rb')
    end
    """
    When I run bash with:
    """
    set -x
    set -e
    cd zold
    gem build zold.gemspec
    gem specification --ruby zold-*.gem > ../spec.rb
    cd ..
    ruby execs.rb
    """
    Then Exit code is zero
