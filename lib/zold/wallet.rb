# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'openssl'
require_relative 'version'
require_relative 'key'
require_relative 'id'
require_relative 'txn'
require_relative 'tax'
require_relative 'copies'
require_relative 'amount'
require_relative 'hexnum'
require_relative 'signature'
require_relative 'txns'
require_relative 'size'
require_relative 'head'

# The wallet.
#
# It is a text file with a name equal to the wallet ID, which is
# a hexadecimal number of 16 digits, for example: "0123456789abcdef".
# More details about its format is in README.md.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # A single wallet
  class Wallet
    # The name of the main production network. All other networks
    # must have different names.
    MAINET = 'zold'

    # The extension of the wallet files
    EXT = '.z'

    # The constructor of the wallet, from the file. The file may be
    # absent at the time of creating the object. Later, don't forget to
    # call init() in order to initialize the wallet, if it's absent.
    def initialize(file)
      unless file.end_with?(Wallet::EXT, Copies::EXT)
        raise "Wallet file must end with #{Wallet::EXT} or #{Copies::EXT}: #{file}"
      end
      @file = File.absolute_path(file)
      @txns = CachedTxns.new(Txns.new(@file))
      @head = CachedHead.new(Head.new(@file))
    end

    def ==(other)
      to_s == other.to_s
    end

    def to_s
      id.to_s
    end

    # Returns a convenient printable mnemo code of the wallet (mostly
    # useful for logs).
    def mnemo
      "#{id}/#{balance.to_zld(4)}/#{txns.count}t/#{digest[0, 6]}/#{Size.new(size)}"
    end

    # Convert the content of the wallet to the text.
    def to_text
      (@head.fetch + [''] + @txns.fetch.map(&:to_text)).join("\n")
    end

    # Returns the network ID of the wallet.
    def network
      n = @head.fetch[0]
      raise "Invalid network name '#{n}'" unless /^[a-z]{4,16}$/.match?(n)
      n
    end

    # Returns the protocol ID of the wallet file.
    def protocol
      v = @head.fetch[1]
      raise "Invalid protocol version name '#{v}'" unless /^[0-9]+$/.match?(v)
      v.to_i
    end

    # Returns TRUE if the wallet file exists.
    def exists?
      File.exist?(path)
    end

    # Returns the absolute path of the wallet file (it may be absent).
    def path
      @file
    end

    # Creates an empty wallet with the specified ID and public key.
    def init(id, pubkey, overwrite: false, network: 'test')
      raise "File '#{path}' already exists" if File.exist?(path) && !overwrite
      raise "Invalid network name '#{network}'" unless /^[a-z]{4,16}$/.match?(network)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{network}\n#{PROTOCOL}\n#{id}\n#{pubkey.to_pub}\n\n")
      @txns.flush
      @head.flush
    end

    # Returns TRUE if it's a root wallet.
    def root?
      id == Id::ROOT
    end

    # Returns the wallet ID.
    def id
      Id.new(@head.fetch[2])
    end

    # Returns current wallet balance.
    def balance
      txns.inject(Amount::ZERO) { |sum, t| sum + t.amount }
    end

    # Add a payment transaction to the wallet.
    def sub(amount, invoice, pvt, details = '-', time: Time.now)
      raise 'The amount has to be of type Amount' unless amount.is_a?(Amount)
      raise "The amount can't be negative: #{amount}" if amount.negative?
      raise 'The pvt has to be of type Key' unless pvt.is_a?(Key)
      prefix, target = invoice.split('@')
      tid = max + 1
      raise 'Too many transactions already, can\'t add more' if max > 0xffff
      txn = Txn.new(
        tid,
        time,
        amount * -1,
        prefix,
        Id.new(target),
        details
      )
      txn = txn.signed(pvt, id)
      raise "Invalid private key for the wallet #{id}" unless Signature.new(network).valid?(key, id, txn)
      add(txn)
      txn
    end

    # Add a transaction to the wallet.
    def add(txn)
      raise 'The txn has to be of type Txn' unless txn.is_a?(Txn)
      raise "Wallet #{id} can't pay itself: #{txn}" if txn.bnf == id
      raise "The amount can't be zero in #{id}: #{txn}" if txn.amount.zero?
      if txn.amount.negative? && includes_negative?(txn.id)
        raise "Negative transaction with the same ID #{txn.id} already exists in #{id}"
      end
      if txn.amount.positive? && includes_positive?(txn.id, txn.bnf)
        raise "Positive transaction with the same ID #{txn.id} and BNF #{txn.bnf} already exists in #{id}"
      end
      raise "The tax payment already exists in #{id}: #{txn}" if Tax.new(self).exists?(txn.details)
      File.open(path, 'a') { |f| f.print "#{txn}\n" }
      @txns.flush
    end

    # Returns TRUE if the wallet contains a payment sent with the specified
    # ID, which was sent to the specified beneficiary.
    def includes_negative?(id, bnf = nil)
      raise 'The txn ID has to be of type Integer' unless id.is_a?(Integer)
      !txns.find { |t| t.id == id && (bnf.nil? || t.bnf == bnf) && t.amount.negative? }.nil?
    end

    # Returns TRUE if the wallet contains a payment received with the specified
    # ID, which was sent by the specified beneficiary.
    def includes_positive?(id, bnf)
      raise 'The txn ID has to be of type Integer' unless id.is_a?(Integer)
      raise 'The bnf has to be of type Id' unless bnf.is_a?(Id)
      !txns.find { |t| t.id == id && t.bnf == bnf && !t.amount.negative? }.nil?
    end

    # Returns TRUE if the public key of the wallet includes this payment
    # prefix of the invoice.
    def prefix?(prefix)
      key.to_pub.include?(prefix)
    end

    # Returns the public key of the wallet.
    def key
      Key.new(text: @head.fetch[3])
    end

    # Returns the time of when the wallet file was recently modified.
    def mtime
      File.mtime(path)
    end

    # Returns a pseudo-unique hexadecimal digest of the wallet content.
    def digest
      OpenSSL::Digest::SHA256.file(path).hexdigest
    end

    # Age of wallet in hours.
    def age
      list = txns
      list.empty? ? 0 : (Time.now - list.min_by(&:date).date) / (60 * 60)
    end

    # Size of the wallet file in bytes. If the file doesn't exist
    # an exception will be raised.
    def size
      raise "The wallet file #{path} doesn't exist" unless File.exist?(path)
      File.size(path)
    end

    # Retrieve the total list of all transactions.
    def txns
      @txns.fetch
    end

    # Resaves the content of the wallet to the disc in the right format. All
    # unnecessary space and EOL-s are removed. This operation is required
    # in order to make sure two wallets with the same content are identical,
    # no matter whether they were formatted differently.
    def refurbish
      File.write(path, "#{(@head.fetch + [''] + @txns.fetch.map(&:to_s)).join("\n")}\n")
      @txns.flush
    end

    # Flush the in-memory cache and force the object to load all data from
    # the disc again.
    def flush
      @head.flush
      @txns.flush
    end

    private

    # Calculate the maximum transaction ID visible currently in the wallet.
    # We go through them all and find the largest number. If there are
    # no transactions, zero is returned.
    def max
      negative = txns.select { |t| t.amount.negative? }
      negative.empty? ? 0 : negative.max_by(&:id).id
    end
  end
end
