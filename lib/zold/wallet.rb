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
    def initialize(file)
      @file = file
    end

    def to_s
      id
    end

    def exists?
      File.exist?(@file)
    end

    def init(id, pubkey)
      raise "File '#{@file}' already exists" if File.exist?(@file)
      File.write(
        @file,
        valid(
          Nokogiri::XML::Builder.new do |xml|
            xml.wallet do
              xml.id_ id.to_s
              xml.pkey pubkey.to_s
              xml.ledger {}
            end
          end.doc
        )
      )
    end

    def id
      load.xpath('/wallet/id/text()').to_s
    end

    def balance
      Amount.new(
        coins: load.xpath('/wallet/ledger/txn/amount/text()')
          .map(&:to_s)
          .map(&:to_i)
          .inject(0) { |sum, n| sum + n }
      )
    end

    def sub(amount, target, pvtkey)
      xml = load
      txn = 1
      unless xml.xpath('/wallet/ledger[txn]').empty?
        txn = xml.xpath('/wallet/ledger/txn/@id').map(&:to_i).max + 1
      end
      date = Time.now
      t = xml.xpath('/wallet/ledger')[0].add_child('<txn/>')[0]
      t['id'] = txn
      t.add_child('<date/>')[0].content = date.iso8601
      t.add_child('<amount/>')[0].content = -amount.to_i
      t.add_child('<beneficiary/>')[0].content = target
      t.add_child('<sign/>')[0].content = pvtkey.sign(
        "#{txn} #{amount.to_i} #{target}"
      )
      save(xml)
      { id: txn, date: date, amount: amount, beneficiary: id }
    end

    def add(txn)
      xml = load
      t = xml.xpath('/wallet/ledger')[0].add_child('<txn/>')[0]
      t['id'] = "/#{txn[:id]}"
      t.add_child('<date/>')[0].content = txn[:date].iso8601
      t.add_child('<amount/>')[0].content = txn[:amount].to_i
      t.add_child('<beneficiary/>')[0].content = txn[:beneficiary]
      save(xml).to_s
    end

    def check(id, amount, beneficiary)
      xml = load
      txn = xml.xpath("/wallet/ledger/txn[@id='#{id}']")[0]
      Amount.new(coins: txn.xpath('amount/text()')[0].to_s.to_i).mul(-1) ==
        amount &&
        txn.xpath('beneficiary/text()')[0].to_s == beneficiary &&
        Key.new(text: xml.xpath('/wallet/pkey/text()')[0].to_s).verify(
          txn.xpath('sign/text()')[0].to_s,
          "#{id} #{amount.to_i} #{beneficiary}"
        )
    end

    def income
      load.xpath('/wallet/ledger/txn[amount > 0]').each do |txn|
        hash = {
          id: txn['id'][1..-1].to_i,
          beneficiary: Id.new(txn.xpath('beneficiary/text()')[0].to_s),
          amount: Amount.new(coins: txn.xpath('amount/text()')[0].to_s.to_i)
        }
        yield hash
      end
    end

    private

    def load
      raise "File '#{@file}' is absent" unless File.exist?(@file)
      valid(Nokogiri::XML(File.read(@file)))
    end

    def save(xml)
      File.write(@file, valid(xml).to_s)
    end

    def valid(xml)
      xsd = Nokogiri::XML::Schema(
        File.open(
          File.join(
            File.dirname(__FILE__),
            '../../assets/wallet.xsd'
          )
        )
      )
      errors = xsd.validate(xml)
      unless errors.empty?
        errors.each do |error|
          puts "#{p} #{error.line}: #{error.message}"
        end
        puts xml
        raise 'XML is not valid'
      end
      xml
    end
  end
end
