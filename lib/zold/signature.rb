# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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

require_relative 'key'
require_relative 'id'
require_relative 'amount'
require_relative 'txn'

# The signature of a transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A signature
  class Signature
    def initialize(network = 'test')
      @network = network
    end

    # Sign the trasnsaction and return the signature.
    # +pvt+:: Private RSA key
    # +id+:: Paying wallet ID
    # +txn+:: The transaction
    def sign(pvt, id, txn)
      raise 'pvt must be of type Key' unless pvt.is_a?(Key)
      raise 'id must be of type Id' unless id.is_a?(Id)
      raise 'txn must be of type Txn' unless txn.is_a?(Txn)
      pvt.sign(body(id, txn))
    end

    # The transaction is valid? Returns true if it is.
    # +pub+:: Public key of the wallet
    # +id+:: Paying wallet ID
    # +txn+: Transaction to validate
    def valid?(pub, id, txn)
      raise 'pub must be of type Key' unless pub.is_a?(Key)
      raise 'id must be of type Id' unless id.is_a?(Id)
      raise 'txn must be of type Txn' unless txn.is_a?(Txn)
      pub.verify(txn.sign, body(id, txn)) && (@network != Wallet::MAINET || !id.root? || pub.root?)
    end

    private

    # Create the body for transaction signature.
    # +id+:: The paying wallet ID
    # +t+:: Transaction, instance of Txn
    def body(id, t)
      [id, t.id, t.date.utc.iso8601, t.amount.to_i, t.prefix, t.bnf, t.details].join(' ')
    end
  end
end
