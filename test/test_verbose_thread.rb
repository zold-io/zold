# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/zold/verbose_thread'

# VerboseThread test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestVerboseThread < Zold::Test
  def test_exceptions_are_logged
    assert_raises RuntimeError do
      Zold::VerboseThread.new(Loog::NULL).run do
        raise 'Intentional'
      end
    end
  end

  def test_syntax_exceptions_are_logged
    assert_raises NoMethodError do
      Zold::VerboseThread.new(Loog::NULL).run do
        this_method_doesnt_exist(1)
      end
    end
  end

  def test_grammar_exceptions_are_logged
    assert_raises NameError do
      Zold::VerboseThread.new(Loog::NULL).run do
        the syntax is broken here
      end
    end
  end
end
