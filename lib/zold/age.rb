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

require 'time'
require 'rainbow'

# Age in seconds.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Age
  class Age
    def initialize(time, limit: nil)
      @time = time.nil? || time.is_a?(Time) ? time : Time.parse(time)
      @limit = limit
    end

    def to_s
      return '?' if @time.nil?
      sec = Time.now - @time
      txt = text(sec)
      if !@limit.nil? && sec > @limit
        Rainbow(txt).red
      else
        txt
      end
    end

    private

    def text(sec)
      return "#{(sec * 1000).round}ms" if sec < 1
      return "#{sec.round(2)}s" if sec < 60
      return "#{(sec / 60).round}m" if sec < 60 * 60
      "#{(sec / 3600).round}h"
    end
  end
end
