# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'rainbow'

# The amount.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Amount
  class Amount
    MAX = 2**63

    FRACTION = 32
    private_constant :FRACTION

    def initialize(zents: nil, zld: nil)
      if !zents.nil?
        raise(RuntimeError, "Integer is required, while #{zents.class} provided: #{zents}") unless zents.is_a?(Integer)
        @zents = zents
      elsif !zld.nil?
        raise(RuntimeError, "Float is required, while #{zld.class} provided: #{zld}") unless zld.is_a?(Float)
        @zents = (zld * (2**FRACTION)).truncate
      else
        raise(RuntimeError, 'You can\'t specify both coints and zld')
      end
      raise(RuntimeError, "The amount is too big: #{@zents}") if @zents > MAX
      raise(RuntimeError, "The amount is too small: #{@zents}") if @zents < -MAX
    end

    ZERO = Amount.new(zents: 0)

    # Convert it to zents and return as an integer.
    def to_zents
      @zents
    end

    # Convert to ZLD and return as a float.
    def to_f
      Float(@zents) / (2**FRACTION)
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
      raise(RuntimeError, "== may only work with Amount: #{other}") unless other.is_a?(Amount)
      @zents == other.to_zents
    end

    def >(other)
      raise(RuntimeError, '> may only work with Amount') unless other.is_a?(Amount)
      @zents > other.to_zents
    end

    def <(other)
      raise(RuntimeError, '< may only work with Amount') unless other.is_a?(Amount)
      @zents < other.to_zents
    end

    def <=(other)
      raise(RuntimeError, '<= may only work with Amount') unless other.is_a?(Amount)
      @zents <= other.to_zents
    end

    def <=>(other)
      raise(RuntimeError, '<= may only work with Amount') unless other.is_a?(Amount)
      @zents <=> other.to_zents
    end

    def +(other)
      raise(RuntimeError, '+ may only work with Amount') unless other.is_a?(Amount)
      Amount.new(zents: @zents + other.to_zents)
    end

    def -(other)
      raise(RuntimeError, '- may only work with Amount') unless other.is_a?(Amount)
      Amount.new(zents: @zents - other.to_zents)
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
      raise(RuntimeError, '* may only work with a number') unless other.is_a?(Integer) || other.is_a?(Float)
      c = (@zents * other).truncate
      raise(RuntimeError, "Overflow, can't multiply #{@zents} by #{m}") if c > MAX
      Amount.new(zents: c)
    end

    def /(other)
      raise(RuntimeError, '/ may only work with a number') unless other.is_a?(Integer) || other.is_a?(Float)
      Amount.new(zents: (@zents / other).truncate)
    end
  end
end
