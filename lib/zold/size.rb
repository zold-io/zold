# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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

require 'time'

# Size in bytes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
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
