# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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
    # Maximum amount of zents
    MAX = 2**63

    # How many zents are in one ZLD: 2^FRACTION
    FRACTION = 32
    private_constant :FRACTION

    def initialize(zents: nil, zld: nil)
      if !zents.nil?
        raise "Integer is required, while #{zents.class} provided: #{zents}" unless zents.is_a?(Integer)
        @zents = zents
      elsif !zld.nil?
        raise "Float is required, while #{zld.class} provided: #{zld}" unless zld.is_a?(Float)
        @zents = (zld * (2**FRACTION)).to_i
      else
        raise 'You can\'t specify both coints and zld'
      end
      raise "The amount is too big: #{@zents}" if @zents > MAX
      raise "The amount is too small: #{@zents}" if @zents < -MAX
    end

    # Just zero, for convenience.
    ZERO = Amount.new(zents: 0)

    # Convert it to zents and return as an integer.
    def to_i
      @zents
    end

    # Convert to ZLD and return as a float.
    def to_f
      @zents.to_f / (2**FRACTION)
    end

    # Convert to ZLD and return as a string. If you need float, you should use <tt>to_f()</tt> later.
    def to_zld(digits = 2)
      format("%0.#{digits}f", to_f)
    end

    def to_s
      text = "#{to_zld}ZLD"
      if positive?
        Rainbow(text).green
      elsif negative?
        Rainbow(text).red
      else
        text
      end
    end

    def ==(other)
      raise "== may only work with Amount: #{other}" unless other.is_a?(Amount)
      @zents == other.to_i
    end

    def >(other)
      raise '> may only work with Amount' unless other.is_a?(Amount)
      @zents > other.to_i
    end

    def <(other)
      raise '< may only work with Amount' unless other.is_a?(Amount)
      @zents < other.to_i
    end

    def <=(other)
      raise '<= may only work with Amount' unless other.is_a?(Amount)
      @zents <= other.to_i
    end

    def <=>(other)
      raise '<= may only work with Amount' unless other.is_a?(Amount)
      @zents <=> other.to_i
    end

    def +(other)
      raise '+ may only work with Amount' unless other.is_a?(Amount)
      Amount.new(zents: @zents + other.to_i)
    end

    def -(other)
      raise '- may only work with Amount' unless other.is_a?(Amount)
      Amount.new(zents: @zents - other.to_i)
    end

    def zero?
      @zents.zero?
    end

    def negative?
      @zents.negative?
    end

    def positive?
      @zents.positive?
    end

    def *(other)
      raise '* may only work with a number' unless other.is_a?(Integer) || other.is_a?(Float)
      c = (@zents * other).to_i
      raise "Overflow, can't multiply #{@zents} by #{m}" if c > MAX
      Amount.new(zents: c)
    end

    def /(other)
      raise '/ may only work with a number' unless other.is_a?(Integer) || other.is_a?(Float)
      Amount.new(zents: (@zents / other).to_i)
    end
  end
end
