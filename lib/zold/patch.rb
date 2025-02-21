# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'openssl'
require_relative 'log'
require_relative 'wallet'
require_relative 'signature'

# Patch.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # A patch
  class Patch
    def initialize(wallets, log: Log::NULL)
      @wallets = wallets
      @txns = []
      @log = log
    end

    def to_s
      return 'nothing' if @txns.empty?
      "#{@txns.count} txns"
    end

    # Add legacy transactions first, since they are negative and can't
    # be deleted ever. This method is called by merge.rb in order to add
    # legacy negative transactions to the patch before everything else. They
    # are not supposed to be disputed, ever.
    def legacy(wallet, hours: 24)
      raise 'You can\'t add legacy to a non-empty patch' unless @id.nil?
      wallet.txns.each do |txn|
        @txns << txn if txn.amount.negative? && txn.date < Time.now - (hours * 60 * 60)
      end
    end

    # Joins a new wallet on top of existing patch. An attempt is made to
    # copy as many transactions from the newcoming wallet to the existing
    # set of transactions, avoiding mistakes and duplicates.
    #
    # A block has to be given. It will be called, if a paying wallet is absent.
    # The block will have to return either TRUE or FALSE. TRUE will mean that
    # the paying wallet has to be present and we just tried to pull it. If it's
    # not present, it's a failure, don't accept the transaction. FALSE will mean
    # that the transaction should be accepted, even if the paying wallet is
    # absent.
    #
    # The "baseline" flag, when set to TRUE, means that we should NOT validate
    # the presence of positive incoming transactions in their correspondent
    # wallets. We shall just trust them.
    #
    # If the "master" flag is set, this copy is coming from a master node
    # and we should allow it to overwrite negative transactions.
    def join(wallet, ledger: '/dev/null', baseline: false, master: false)
      if @id.nil?
        @id = wallet.id
        @key = wallet.key
        @network = wallet.network
      end
      unless wallet.network == @network
        @log.error("The wallet is from a different network '#{wallet.network}', ours is '#{@network}'")
        return
      end
      unless wallet.key == @key
        @log.error('Public key mismatch')
        return
      end
      unless wallet.id == @id
        @log.error("Wallet ID mismatch, ours is #{@id}, theirs is #{wallet.id}")
        return
      end
      seen = 0
      added = 0
      pulled = []
      wallet.txns.each do |txn|
        next if @txns.find { |t| t == txn }
        seen += 1
        if txn.amount.negative?
          dup = @txns.find { |t| t.id == txn.id && t.amount.negative? }
          if dup && !master
            @log.error("An attempt to overwrite existing transaction #{dup.to_text.inspect} \
with a new one #{txn.to_text.inspect} from #{wallet.mnemo}")
            next
          end
          if dup && master
            @log.debug("An overwrite to the existing transaction #{dup.to_text.inspect} \
is coming from a master node: #{txn.to_text.inspect} from #{wallet.mnemo}")
            @txns.reject! { |t| t.id == txn.id && t.amount.negative? }
          end
          unless Signature.new(@network).valid?(@key, wallet.id, txn)
            @log.error("Invalid RSA signature at the transaction ##{txn.id} of #{wallet.id}: #{txn.to_text.inspect}")
            next
          end
        else
          if Id::BANNED.include?(txn.bnf.to_s)
            @log.debug("The paying wallet is banned, #{wallet.id} can't accept this: #{txn.to_text.inspect}")
            next
          end
          dup = @txns.find { |t| t.id == txn.id && t.bnf == txn.bnf && t.amount.positive? }
          if dup
            @log.error("Overwriting #{dup.to_text.inspect} with #{txn.to_text.inspect} \
from #{wallet.mnemo} (same ID/BNF)")
            next
          end
          if !txn.sign.nil? && !txn.sign.empty?
            @log.error("RSA signature is redundant at ##{txn.id} of #{wallet.id}: #{txn.to_text.inspect}")
            next
          end
          unless wallet.prefix?(txn.prefix)
            @log.debug("Payment prefix '#{txn.prefix}' doesn't match \
with the key of #{wallet.id}: #{txn.to_text.inspect}")
            next
          end
          unless @wallets.acq(txn.bnf, &:exists?)
            if baseline
              @log.debug("Paying wallet #{txn.bnf} is absent, \
but the txn in in the baseline: #{txn.to_text.inspect}")
            else
              next if pulled.include?(txn.bnf)
              pulled << txn.bnf
              if yield(txn) && !@wallets.acq(txn.bnf, &:exists?)
                @log.error("Paying wallet #{txn.bnf} file is absent even after PULL: #{txn.to_text.inspect}")
                next
              end
            end
          end
          if @wallets.acq(txn.bnf, &:exists?) &&
            !@wallets.acq(txn.bnf) { |p| p.includes_negative?(txn.id, wallet.id) }
            if baseline
              @log.debug("The beneficiary #{@wallets.acq(txn.bnf, &:mnemo)} of #{@id} \
doesn't have this transaction, but we trust it, since it's a baseline: #{txn.to_text.inspect}")
            else
              if pulled.include?(txn.bnf)
                @log.debug("The beneficiary #{@wallets.acq(txn.bnf, &:mnemo)} of #{@id} \
doesn't have this transaction: #{txn.to_text.inspect}")
                next
              end
              pulled << txn.bnf
              yield(txn)
              unless @wallets.acq(txn.bnf) { |p| p.includes_negative?(txn.id, wallet.id) }
                @log.debug("The beneficiary #{@wallets.acq(txn.bnf, &:mnemo)} of #{@id} \
doesn't have this transaction: #{txn.to_text.inspect}")
                next
              end
            end
          end
        end
        @txns << txn
        added += 1
        next unless txn.amount.negative?
        File.open(ledger, 'a') do |f|
          msg = [
            Time.now.utc.iso8601,
            txn.id,
            txn.date.utc.iso8601,
            wallet.id,
            txn.bnf,
            txn.amount.to_i * -1,
            txn.prefix,
            txn.details
          ].map(&:to_s).join(';')
          f.puts("#{msg}\n")
        end
      end
    end

    def empty?
      @id.nil?
    end

    # Returns TRUE if the file was actually modified
    def save(file, overwrite: false, allow_negative_balance: false)
      raise 'You have to join at least one wallet in' if empty?
      before = ''
      wallet = Wallet.new(file)
      before = wallet.digest if wallet.exists?
      Tempfile.open([@id, Wallet::EXT]) do |f|
        temp = Wallet.new(f.path)
        temp.init(@id, @key, overwrite: overwrite, network: @network)
        File.open(f.path, 'a') do |t|
          @txns.each do |txn|
            next if Id::BANNED.include?(txn.bnf.to_s)
            t.print "#{txn}\n"
          end
        end
        temp.refurbish
        if temp.balance.negative? && !temp.id.root? && !allow_negative_balance
          if wallet.exists?
            @log.info("The balance is negative, won't merge #{temp.mnemo} on top of #{wallet.mnemo}")
          else
            @log.info("The balance is negative, won't save #{temp.mnemo}")
          end
        else
          FileUtils.mkdir_p(File.dirname(file))
          File.write(file, File.read(f.path))
        end
      end
      before != wallet.digest
    end
  end
end
