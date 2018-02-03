# Copyright (c) 2018 Zerocracy, Inc.
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

# The amount.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
module Zold
  # Amount
  class Amount
    def initialize(coins: nil, zld: nil)
      raise 'You can\'t specify both coints and zld' if !coins.nil? && !zld.nil?
      @coins = coins unless coins.nil?
      @coins = (zld * 2**24).to_i unless zld.nil?
    end

    def to_i
      @coins
    end

    def to_zld
      @coins / 2**24
    end

    def to_s
      "#{to_zld}ZLD"
    end

    def ==(other)
      @coins == other.to_i
    end

    def zero?
      @coins.zero?
    end

    def negative?
      @coins < 0
    end

    def mul(m)
      c = @coins * m
      raise "Overflow, can't multiply #{@coins} by #{m}" if c > 2**63
      Amount.new(coins: c)
    end
  end
end
