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
require_relative 'id'
require_relative 'amount'
require_relative 'signature'

# The transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A single transaction
  class Txn
    attr_reader :id, :date, :amount, :prefix, :bnf, :details, :sign
    attr_writer :sign, :amount
    def initialize(id, date, amount, prefix, bnf, details)
      raise "ID of transaction can't be negative: #{id}" if id < 1
      @id = id
      raise 'Time have to be of type Time' unless date.is_a?(Time)
      raise "Time can't be in the future: #{date}" if date > Time.now
      @date = date
      raise 'The amount has to be of type Amount' unless amount.is_a?(Amount)
      raise 'The amount can\'t be zero' if amount.zero?
      @amount = amount
      raise 'The bnf has to be of type Id' unless bnf.is_a?(Id)
      @bnf = bnf
      raise "Prefix is too short: \"#{prefix}\"" if prefix.length < 8
      raise "Prefix is too long: \"#{prefix}\"" if prefix.length > 32
      @prefix = prefix
      raise 'Details can\'t be empty' if details.empty?
      raise "Details are too long: \"#{details}\"" if details.length > 128
      @details = details
    end

    def ==(other)
      id == other.id && bnf == other.bnf
    end

    def to_s
      [
        @id,
        @date.utc.iso8601,
        @amount.to_i,
        @prefix,
        @bnf,
        @details,
        @sign
      ].join(';')
    end

    def inverse
      t = clone
      t.amount = amount.mul(-1)
      t
    end

    def signed(pvt)
      t = clone
      t.sign = Signature.new.sign(pvt, self)
      t
    end

    def self.parse(line, idx)
      regex = Regexp.new(
        [
          '([0-9]+)',
          '([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          '(-?[0-9]+)',
          '([A-Za-z0-9]{8,32})',
          '([a-f0-9]{16})',
          '([a-zA-Z0-9 -.]{1,128})',
          '([A-Za-z0-9+/]+={0,3})?'
        ].join(';')
      )
      clean = line.strip
      raise "Invalid line ##{idx}: #{line.inspect}" unless regex.match(clean)
      parts = clean.split(';')
      txn = Txn.new(
        parts[0].to_i,
        Time.parse(parts[1]),
        Amount.new(coins: parts[2].to_i),
        parts[3],
        Id.new(parts[4]),
        parts[5]
      )
      txn.sign = parts[6]
      txn
    end
  end
end
