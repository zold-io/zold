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

  Scenario: Failure through nohup
    When I run bin/zold-nohup with "badcommand --skip-install --log-file=log.txt; sleep 2; cat log.txt"
    And Stdout contains "Command 'badcommand' is not supported"
    Then Exit code is zero
