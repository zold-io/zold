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
require_relative 'key'
require_relative 'id'
require_relative 'txn'
require_relative 'amount'
require_relative 'signature'

# The wallet.
#
# It is a text file with a name equal to the wallet ID, which is
# a hexadecimal number of 16 digits, for example: "0123456789abcdef".
# More details about its format is in README.md.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A single wallet
  class Wallet
    def initialize(file)
      @file = file
    end

    def ==(other)
      to_s == other.to_s
    end

    def to_s
      id.to_s
    end

    def exists?
      File.exist?(@file)
    end

    def path
      @file
    end

    def init(id, pubkey, overwrite: false)
      raise "File '#{@file}' already exists" if File.exist?(@file) && !overwrite
      File.write(@file, "#{id}\n#{pubkey.to_pub}\n\n")
    end

    def root?
      id == Id::ROOT
    end

    def id
      Id.new(lines[0])
    end

    def balance
      txns.inject(Amount::ZERO) { |sum, t| sum + t.amount }
    end

    def sub(amount, invoice, pvtkey, details = '-')
      raise "The amount can't be negative: #{amount}" if amount.negative?
      if invoice.is_a?(Id)
        prefix = 'NOPREFIX'
        target = invoice.to_s
      else
        prefix, target = invoice.split('@')
      end
      txn = Txn.new(
        max + 1,
        Time.now,
        amount.mul(-1),
        prefix,
        Id.new(target),
        details
      )
      txn = txn.signed(pvtkey)
      add(txn)
      txn
    end

    def add(txn)
      open(@file, 'a') { |f| f.print "#{txn}\n" }
    end

    def has?(id, bnf)
      !txns.find { |t| t.id == id && t.bnf == bnf }.nil?
    end

    def key
      Key.new(text: lines[1].strip)
    end

    def income
      txns.each do |t|
        yield t unless t.amount.negative?
      end
    end

    def txns
      lines.drop(3)
        .each_with_index
        .map { |line, i| Txn.parse(line, i + 4) }
        .sort_by(&:date)
    end

    private

    def max
      all = txns
      if all.empty?
        0
      else
        all.select { |t| t.amount.negative? }.max_by(&:id).id
      end
    end

    def lines
      raise "File '#{@file}' is absent" unless File.exist?(@file)
      File.readlines(@file)
    end
  end
end
