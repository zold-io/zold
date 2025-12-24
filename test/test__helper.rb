# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

gem 'openssl'
require 'openssl'
require 'minitest/hooks/test'
require 'concurrent'
require 'timeout'

$stdout.sync = true

ENV['RACK_ENV'] = 'test'
require 'simplecov'
require 'simplecov-cobertura'
unless SimpleCov.running || ENV['PICKS']
  SimpleCov.command_name('test')
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
  SimpleCov.minimum_coverage 85
  SimpleCov.minimum_coverage_by_file 60
  SimpleCov.start do
    add_filter 'test/'
    add_filter 'vendor/'
    add_filter 'target/'
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/autorun'
require 'minitest/reporters'
require 'webmock/minitest'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
Minitest.load :minitest_reporter

require_relative '../lib/zold/hands'
Zold::Hands.start

module Zold
  class Test < Minitest::Test
    include Minitest::Hooks

    # We need this in order to make sure any test is faster than a minute. This
    # should help spotting tests that hang out sometimes. The number of seconds
    # to wait can be increased, but try to make it as little as possible,
    # in order to catch problems ealier.
    def around
      Timeout.timeout(180) do
        Thread.current.name = 'test'
        super
      end
    end

    def assert_wait(max: 30, &block)
      assert_equal_wait(true, max: max, &block)
    end

    def assert_equal_wait(expected, max: 30)
      start = Time.now
      loop do
        begin
          actual = yield
          if expected == actual
            assert_equal(expected, actual)
            break
          end
        rescue StandardError => e
          fake_log.debug(e.message)
        end
        sleep 1
        sec = Time.now - start
        require_relative '../lib/zold/age'
        raise "'#{actual}' is not equal to '#{expected}' even after #{Zold::Age.new(start)} of waiting" if sec > max
      end
    end

    def fake_log
      require 'loog'
      @fake_log ||= ENV['TEST_QUIET_LOG'] == 'true' ? Loog::NULL : Loog::VERBOSE
    end

    class TestLogger
      attr_accessor :msgs

      def initialize(log = Loog::NULL)
        @log = log
        @msgs = []
      end

      def info(msg)
        @log.info(msg)
        @msgs << msg
      end

      def debug(msg)
        @log.debug(msg)
        @msgs << msg
      end

      def error(msg)
        @log.error(msg)
        @msgs << msg
      end
    end
  end
end
