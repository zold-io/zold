# encoding: utf-8

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

require 'nokogiri'
require 'time'

# The wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
module Zold
  # A single wallet
  class Wallet
    def initialize(file, pvtkey = nil)
      @file = file
      @pvtkey = pvtkey
    end

    def to_s
      "Z#{id}"
    end

    def init(id, pubkey)
      File.write(
        @file,
        Nokogiri::XML::Builder.new do |xml|
          xml.wallet do
            xml.id_ id
            xml.pkey pubkey
            xml.ledger {}
          end
        end.to_xml
      )
    end

    def id
      Nokogiri::XML(File.read(@file)).xpath('/wallet/id/text()').to_s.to_i
    end

    def sub(amount, target)
      txn = 1
      date = Time.now.iso8601
      Nokogiri::XML(File.read(@file)).xpath('/wallet/ledger')[0].add_child(
        Nokogiri::XML::Builder.new do |xml|
          xml.txn do
            xml.id_ txn
            xml.date date
            xml.amount amount
            xml.beneficiary target
            xml.sign '???'
          end
        end.to_s
      )
      { id: txn, date: date, amount: amount, beneficiary: id }
    end

    def add(txn)
      Nokogiri::XML(File.read(@file)).xpath('/wallet/ledger')[0].add_child(
        Nokogiri::XML::Builder.new do |xml|
          xml.txn do
            xml.id_ "/#{txn[:id]}"
            xml.date txn[:date]
            xml.amount txn[:amount]
            xml.beneficiary txn[:beneficiary]
          end
        end.to_s
      )
    end
  end
end
