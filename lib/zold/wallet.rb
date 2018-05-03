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
      all.empty? ? 0 : all.map { |t| t[:id] }.max
    end

    def root?
      id == Id::ROOT
    end

    def id
      Id.new(lines[0])
    end

    def balance
      txns.inject(Amount::ZERO) { |sum, t| sum + t[:amount] }
    end

    def sub(amount, target, pvtkey, details = '-')
      txn = {
        id: version + 1,
        date: Time.now,
        amount: amount.mul(-1),
        beneficiary: target,
        details: details
      }
      txn[:sign] = pvtkey.sign(signature(txn))
      File.write(@file, (lines << to_line(txn)).join)
      txn[:amount] = amount
      txn
    end

    def add(txn)
      File.write(@file, (lines << to_line(txn)).join)
    end

    def check(id, amount, beneficiary)
      txn = txns.find { |t| t[:id] == id }
      raise "Transaction #{id} not found" if txn.nil?
      xamount = txn[:amount].mul(-1)
      raise "#{xamount} != #{amount}" if xamount != amount
      xbeneficiary = txn[:beneficiary]
      raise "#{xbeneficiary} != #{beneficiary}" if xbeneficiary != beneficiary
      valid = Key.new(text: lines[1].strip).verify(txn[:sign], signature(txn))
      raise "Signature is not valid for '#{signature(txn)}'" unless valid
      true
    end

    def income
      txns.each do |t|
        yield t unless t[:amount].negative?
      end
    end

    private

    def to_line(txn)
      [
        txn[:id],
        txn[:date].utc.iso8601,
        txn[:amount].to_i,
        txn[:beneficiary],
        txn[:details],
        txn[:sign]
      ].join(';') + "\n"
    end

    def fields(line)
      regex = Regexp.new(
        '(' + [
          '[0-9]+',
          '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z',
          '-?[0-9]+',
          '[a-f0-9]{16}',
          '[a-zA-Z0-9 -.]{1,128}',
          '[A-Za-z0-9+/]*={0,3}'
        ].join(');(') + ')'
      )
      raise "Invalid line: #{line}" unless regex.match?(line)
      parts = line.split(';')
      {
        id: parts[0].to_i,
        date: Time.parse(parts[1]),
        amount: Amount.new(coins: parts[2].to_i),
        beneficiary: Id.new(parts[3]),
        details: parts[4],
        sign: parts[5]
      }
    end

    def signature(txn)
      "#{txn[:id]};#{txn[:amount].to_i};#{txn[:beneficiary]};#{txn[:details]}"
    end

    def txns
      lines.drop(3).map { |t| fields(t) }
    end

    def lines
      raise "File '#{@file}' is absent" unless File.exist?(@file)
      File.readlines(@file)
    end
  end
end
