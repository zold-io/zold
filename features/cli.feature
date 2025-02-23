# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT
Feature: Command Line Processing
  As an payment originator I want to be able to use
  Zold as a command line tool

  Scenario: Help can be printed
    When I run bin/zold with "-h"
    Then Exit code is zero
    And Stdout contains "--help"

  Scenario: Version can be printed
    When I run bin/zold with "--version"
    Then Exit code is zero

  Scenario: Wallet can be created
    When I run bin/zold with "--trace --public-key=id_rsa.pub create"
    Then Exit code is zero
