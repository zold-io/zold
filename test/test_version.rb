# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'semantic'
require 'zold/version'

class TestVersion < Zold::Test
  def test_has_version
    assert Semantic::Version.new(Zold::VERSION)
  end

  def test_has_protocol
    assert Zold::PROTOCOL
  end
end
