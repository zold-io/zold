# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest'

# Test only module
module Assertions
  extend Minitest::Assertions

  class << self
    attr_accessor :assertions
  end
  self.assertions = 0
end

def assert_equal(a, b)
  Assertions.assert_equal(a, b)
end
