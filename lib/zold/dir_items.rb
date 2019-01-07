# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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

require 'shellwords'

# Items in a directory.
#
# We need this class because Dir.new() from Ruby is blocking. It doesn't
# allow to write and read to any files in a directory, while listing it.
# More: https://stackoverflow.com/questions/52987672/
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
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
        .split(' ')
        .select { |f| f.start_with?(@dir) && f.length > @dir.length }
        .map { |f| f[(@dir.length + 1)..-1] }
    end
  end
end
