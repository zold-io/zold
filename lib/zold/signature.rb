# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'key'
require_relative 'id'
require_relative 'amount'
require_relative 'txn'

# The signature of a transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
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
