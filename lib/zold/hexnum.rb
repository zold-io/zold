# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Hex num.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # A hex num
  class Hexnum
    def initialize(num, length)
      @num = num
      @length = length
    end

    def to_i
      @num
    end

    def to_s
      format("%0#{@length}x", @num).gsub(/^\.{2}/, 'ff')
    end

    def self.parse(txt)
      n = Integer("0x#{txt}", 16)
      if txt.start_with?('f')
        max = Integer("0x#{'f' * txt.length}", 16)
        n = n - max - 1
      end
      Hexnum.new(n, txt.length)
    end
  end
end
