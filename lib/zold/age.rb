# frozen_string_literal: true

# Copyright (c) 2018-2025 Zerocracy
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
require_relative 'txn'

# Age in seconds.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Age
  class Age
    def initialize(time, limit: nil)
      @time = time.nil? || time.is_a?(Time) ? time : Txn.parse_time(time)
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
      return "#{(sec * 1_000_000).round}μs" if sec < 0.001
      return "#{(sec * 1000).round}ms" if sec < 1
      return "#{sec.round(2)}s" if sec < 60
      return "#{(sec / 60).round}m" if sec < 60 * 60
      hours = (sec / 3600).round
      return "#{hours}h" if hours < 24
      days = (hours / 24).round
      return "#{days}d" if days < 14
      return "#{(days / 7).round}w" if days < 40
      return "#{(days / 30).round}mo" if days < 365
      "#{(days / 365).round}y"
    end
  end
end
