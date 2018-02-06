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

require 'time'

# The wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
module Zold
  # A single wallet
  class Wallet
    def initialize(file)
      @file = file
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

    def init(id, pubkey)
      raise "File '#{@file}' already exists" if File.exist?(@file)
      File.write(@file, "#{id}\n#{pubkey.to_pub}\n\n")
    end

    def version
      all = txns
      all.empty? ? 0 : all.map { |t| t[0] }.map(&:to_i).max
    end

    def root?
      id == Id::ROOT
    end

    def id
      Id.new(lines[0])
    end

    def balance
      Amount.new(
        coins: txns.map { |t| t[2] }.map(&:to_i).inject(0) { |sum, n| sum + n }
      )
    end

    def sub(amount, target, pvtkey)
      date = Time.now
      txn = version + 1
      line = [
        txn,
        date.iso8601,
        -amount.to_i,
        target,
        pvtkey.sign("#{txn};#{amount.to_i};#{target}")
      ].join(';') + "\n"
      File.write(@file, (lines << line).join(''))
      {
        id: txn,
        date: date,
        amount: amount,
        beneficiary: id
      }
    end

    def add(txn)
      line = [
        "/#{txn[:id]}",
        txn[:date].iso8601,
        txn[:amount].to_i,
        txn[:beneficiary]
      ].join(';') + "\n"
      File.write(@file, (lines << line).join(''))
    end

    def check(id, amount, beneficiary)
      txn = txns.find { |t| t[0].to_i == id }
      raise "Transaction ##{id} not found" if txn.nil?
      xamount = Amount.new(coins: txn[2].to_i).mul(-1)
      raise "#{xamount} != #{amount}" if xamount != amount
      xbeneficiary = Id.new(txn[3].to_s)
      raise "#{xbeneficiary} != #{beneficiary}" if xbeneficiary != beneficiary
      data = "#{id};#{amount.to_i};#{beneficiary}"
      valid = Key.new(text: lines[1].strip).verify(txn[4], data)
      raise "Signature is not confirming this data: '#{data}'" unless valid
      true
    end

    def income
      txns.select { |t| t[2].to_i > 0 }.each do |t|
        hash = {
          id: t[0][1..-1].to_i,
          beneficiary: Id.new(t[3]),
          amount: Amount.new(coins: t[2].to_i)
        }
        yield hash
      end
    end

    private

    def txns
      lines.drop(3).map { |t| t.split(';') }
    end

    def lines
      raise "File '#{@file}' is absent" unless File.exist?(@file)
      File.readlines(@file)
    end
  end
end
