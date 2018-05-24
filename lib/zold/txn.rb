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
require_relative 'hexnum'
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
    attr_writer :sign, :amount, :bnf
    def initialize(id, date, amount, prefix, bnf, details)
      raise 'The ID can\'t be NIL' if id.nil?
      raise "ID of transaction can't be negative: #{id}" if id < 1
      @id = id
      raise 'The time can\'t be NIL' if date.nil?
      raise 'Time have to be of type Time' unless date.is_a?(Time)
      raise "Time can't be in the future: #{date}" if date > Time.now
      @date = date
      raise 'The amount can\'t be NIL' if amount.nil?
      raise 'The amount has to be of type Amount' unless amount.is_a?(Amount)
      raise 'The amount can\'t be zero' if amount.zero?
      @amount = amount
      raise 'The bnf can\'t be NIL' if bnf.nil?
      raise 'The bnf has to be of type Id' unless bnf.is_a?(Id)
      @bnf = bnf
      raise 'Prefix can\'t be NIL' if prefix.nil?
      raise "Prefix is too short: \"#{prefix}\"" if prefix.length < 8
      raise "Prefix is too long: \"#{prefix}\"" if prefix.length > 32
      raise "Prefix is wrong: \"#{prefix}\"" unless prefix =~ /^[a-zA-Z0-9]+$/
      @prefix = prefix
      raise 'Details can\'t be NIL' if details.nil?
      raise 'Details can\'t be empty' if details.empty?
      raise "Details are too long: \"#{details}\"" if details.length > 512
      raise "Details are wrong: \"#{details}\"" unless details =~ /^[a-zA-Z0-9 -\.,]+$/
      @details = details
    end

    def ==(other)
      id == other.id && bnf == other.bnf
    end

    def to_s
      [
        Hexnum.new(@id, 4).to_s,
        @date.utc.iso8601,
        Hexnum.new(@amount.to_i, 16),
        @prefix,
        @bnf,
        @details,
        @sign
      ].join(';')
    end

    def to_text
      "##{@id} #{@date.utc.iso8601} #{@amount} #{@bnf} #{@details}"
    end

    def inverse(bnf)
      t = clone
      t.amount = amount * -1
      t.bnf = bnf
      t
    end

    def signed(pvt, id)
      t = clone
      t.sign = Signature.new.sign(pvt, id, self)
      t
    end

    def self.parse(line, idx = 0)
      regex = Regexp.new(
        '^' + [
          '([0-9a-f]{4})',
          '([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          '([0-9a-f]{16})',
          '([A-Za-z0-9]{8,32})',
          '([0-9a-f]{16})',
          '([a-zA-Z0-9 -\.,]{1,512})',
          '([A-Za-z0-9+/]+={0,3})?'
        ].join(';') + '$'
      )
      clean = line.strip
      raise "Invalid line ##{idx}: #{line.inspect}" unless regex.match(clean)
      parts = clean.split(';')
      txn = Txn.new(
        Hexnum.parse(parts[0]).to_i,
        Time.parse(parts[1]),
        Amount.new(coins: Hexnum.parse(parts[2]).to_i),
        parts[3],
        Id.new(parts[4]),
        parts[5]
      )
      txn.sign = parts[6]
      txn
    end
  end
end
