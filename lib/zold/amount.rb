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

require 'rainbow'

# The amount.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Amount
  class Amount
    def initialize(coins: nil, zld: nil)
      raise 'You can\'t specify both coints and zld' if !coins.nil? && !zld.nil?
      @coins = coins unless coins.nil?
      @coins = (zld * 2**24).to_i unless zld.nil?
      raise "Integer is required: #{@coins.class}" unless @coins.is_a?(Integer)
    end

    ZERO = Amount.new(coins: 0)

    def to_i
      @coins
    end

    def to_zld
      format('%0.2f', @coins.to_f / 2**24)
    end

    def to_s
      text = "#{to_zld}ZLD"
      if negative?
        Rainbow(text).red
      else
        Rainbow(text).green
      end
    end

    def ==(other)
      @coins == other.to_i
    end

    def >(other)
      @coins > other.to_i
    end

    def <(other)
      @coins < other.to_i
    end

    def +(other)
      Amount.new(coins: @coins + other.to_i)
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
