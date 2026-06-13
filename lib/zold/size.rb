# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'

# Size in bytes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Size
  class Size
    def initialize(bytes)
      @bytes = bytes
    end

    def to_s
      if @bytes.nil?
        '?'
      elsif @bytes < 1024
        "#{@bytes}b"
      elsif @bytes < 1024 * 1024
        "#{(@bytes / 1024).round}Kb"
      elsif @bytes < 1024 * 1024 * 1024
        "#{(@bytes / (1024 * 1024)).round}Mb"
      else
        "#{(@bytes / (1024 * 1024 * 1024)).round}Gb"
      end
    end
  end
end
