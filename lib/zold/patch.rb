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

require_relative 'wallet'

# Patch.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A patch
  class Patch
    def start(wallet)
      @id = wallet.id
      @key = wallet.key
      @txns = wallet.txns
    end

    def join(wallet)
      negative = @txns.select { |t| t.amount.negative? }
      max = negative.empty? ? 0 : negative.max_by(&:id).id
      wallet.txns.each do |txn|
        next if @txns.find { |t| t == txn }
        next if
          txn.amount.negative? && !@txns.empty? &&
          (txn.id <= max ||
          @txns.find { |t| t.id == txn.id } ||
          @txns.map(&:amount).inject(&:+) < txn.amount)
        next unless Signature.new.valid?(@key, txn)
        @txns << txn
      end
    end

    def save(file, overwrite: false)
      wallet = Zold::Wallet.new(file)
      wallet.init(@id, @key, overwrite: overwrite)
      @txns.each { |t| wallet.add(t) }
    end
  end
end
