# frozen_string_literal: true

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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'logger'
require 'rainbow'

# Zold module.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
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
      colored(prefix, severity) + msg.to_s.rstrip.gsub(/\n/, "\n" + (' ' * prefix.length)) + "\n"
    end

    # Short formatter
    SHORT = proc do |_severity, _time, _target, msg|
      msg.to_s.rstrip + "\n"
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
    NULL = Logger.new(STDOUT)
    NULL.level = Logger::UNKNOWN
    NULL.freeze

    # Everything, including debug
    VERBOSE = Logger.new(STDOUT)
    VERBOSE.level = Logger::DEBUG
    VERBOSE.formatter = COMPACT
    VERBOSE.freeze

    # Info and errors, no debug info
    REGULAR = Logger.new(STDOUT)
    REGULAR.level = Logger::INFO
    REGULAR.formatter = COMPACT
    REGULAR.freeze

    # Errors only
    ERRORS = Logger.new(STDOUT)
    ERRORS.level = Logger::ERROR
    ERRORS.formatter = COMPACT
    ERRORS.freeze
  end
end
