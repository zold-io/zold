# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'threads'
require_relative 'test__helper'
require_relative '../lib/zold/log'

# Log test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestLog < Zold::Test
  def test_prints_from_many_threads
    Threads.new(20).assert do
      fake_log.debug("This is debug\nand it is multi\nline")
      fake_log.info('This is info')
      fake_log.error('This is error')
    end
  end

  def test_prints_with_various_formatters
    log = Zold::Log::VERBOSE.dup
    log.formatter = Zold::Log::FULL
    log.debug("This is info\nand it is multi\nline")
    log.debug('Works fine?')
    log.debug(true)
    log.debug(1)
  end
end
