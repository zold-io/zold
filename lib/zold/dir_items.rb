# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'shellwords'

# Items in a directory.
#
# We need this class because Dir.new() from Ruby is blocking. It doesn't
# allow to write and read to any files in a directory, while listing it.
# More: https://stackoverflow.com/questions/52987672/
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Items in a dir
  class DirItems
    def initialize(dir)
      @dir = dir
    end

    def fetch(recursive: true)
      `find #{([@dir] + (recursive ? [] : ['-maxdepth', '1']) + ['-type', 'f', '-print']).join(' ')} 2>/dev/null`
        .strip
        .split
        .select { |f| f.start_with?(@dir) && f.length > @dir.length }
        .map { |f| f[(@dir.length + 1)..-1] }
    end
  end
end
