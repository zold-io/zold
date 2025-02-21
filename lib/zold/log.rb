# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'logger'
require 'rainbow'

# Zold module.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Logging facilities.
  #
  # There are a few logging classes, which can be used depending on what
  # you want a user to see. There are three logging levels: INFO, ERROR,
  # and DEBUG. In "quiet" mode the user won't see anything. This logging
  # mode is used only for testing, when we don't want to see absolutely
  # anything in the console. In order to turn off logging entirely, see
  # how we configure it in test__helper.rb
  #
  # The default "regular" logging mode is what a user gets when he/she runs
  # the gem in commmand line without any specific flags. In that case,
  # the user will see only INFO and ERROR messages.
  #
  # In a "verbose" mode the user will see everything, including DEBUG
  # messages. The user turns this mode by using --verbose command line argument.
  #
  module Log
    def self.colored(text, severity)
      case severity
      when 'ERROR', 'FATAL'
        return Rainbow(text).red
      when 'DEBUG'
        return Rainbow(text).yellow
      end
      text
    end

    # Compact formatter
    COMPACT = proc do |severity, _time, _target, msg|
      prefix = ''
      case severity
      when 'ERROR', 'FATAL'
        prefix = 'E: '
      when 'DEBUG'
        prefix = 'D: '
      end
      "#{colored(prefix, severity)}#{msg.to_s.rstrip.gsub("\n", "\n#{' ' * prefix.length}")}\n"
    end

    # Short formatter
    SHORT = proc do |_severity, _time, _target, msg|
      "#{msg.to_s.rstrip}\n"
    end

    # Full formatter
    FULL = proc do |severity, time, _target, msg|
      format(
        "%<time>s %<severity>5s %<msg>s\n",
        time: time.utc.iso8601,
        severity: colored(severity, severity),
        msg: msg.to_s.rstrip
      )
    end

    # No logging at all
    NULL = Logger.new($stdout)
    NULL.level = Logger::UNKNOWN
    NULL.freeze

    # Everything, including debug
    VERBOSE = Logger.new($stdout)
    VERBOSE.level = Logger::DEBUG
    VERBOSE.formatter = COMPACT
    VERBOSE.freeze

    # Info and errors, no debug info
    REGULAR = Logger.new($stdout)
    REGULAR.level = Logger::INFO
    REGULAR.formatter = COMPACT
    REGULAR.freeze

    # Errors only
    ERRORS = Logger.new($stdout)
    ERRORS.level = Logger::ERROR
    ERRORS.formatter = COMPACT
    ERRORS.freeze

    # Tee logger.
    class Tee
      def initialize(first, second)
        @first = first
        @second = second
      end

      def debug(msg)
        @first.debug(msg)
        @second.debug(msg)
      end

      def debug?
        @first.debug? || @second.debug?
      end

      def info(msg)
        @first.info(msg)
        @second.info(msg)
      end

      def info?
        @first.info? || @second.info?
      end

      def error(msg)
        @first.error(msg)
        @second.error(msg)
      end
    end
  end
end
