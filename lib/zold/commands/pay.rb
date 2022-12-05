# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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

require 'slop'
require 'rainbow'
require 'shellwords'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../id'
require_relative '../amount'
require_relative '../log'

# PAY command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Money sending command
  class Pay
    prepend ThreadBadge

    def initialize(wallets:, remotes:, copies:, log: Log::NULL)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    # Sends a payment and returns the transaction just created in the
    # paying wallet, an instance of Zold::Txn
    def run(args = [])
      @log.debug("Pay.run(#{args.join(' ')})")
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold pay wallet target amount [details] [options]
Where:
    'wallet' is the sender's wallet ID
    'target' is the beneficiary (either wallet ID or invoice number)'
    'amount' is the amount to pay, for example: '14.95Z' (in ZLD) or '12345z' (in zents)
    'details' is the optional text to attach to the payment
Available options:"
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          require: true,
          default: File.expand_path('~/.ssh/id_rsa')
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.bool '--force',
          'Ignore all validations',
          default: false
        o.string '--time',
          "Time of transaction (default: #{Time.now.utc.iso8601})",
          default: Time.now.utc.iso8601
        o.string '--keygap',
          'Keygap, if the private RSA key is not complete',
          default: ''
        o.bool '--tolerate-edges',
          'Don\'t fail if only "edge" (not "master" ones) nodes have the wallet',
          default: false
        o.integer '--tolerate-quorum',
          'The minimum number of nodes required for a successful fetch (default: 4)',
          default: 4
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak (when paying taxes)',
          default: false
        o.bool '--dont-pay-taxes',
          'Don\'t pay taxes even if the wallet is in debt',
          default: false
        o.bool '--pay-taxes-anyway',
          'Pay taxes even if the wallet is not in debt',
          default: false
        o.bool '--skip-propagate',
          'Don\'t propagate the paying wallet after successful pay',
          default: false
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'Payer wallet ID is required as the first argument' if mine[0].nil?
      id = Id.new(mine[0])
      raise 'Recepient\'s invoice or wallet ID is required as the second argument' if mine[1].nil?
      invoice = mine[1]
      unless invoice.include?('@')
        require_relative 'invoice'
        invoice = Invoice.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
          ['invoice', invoice, "--tolerate-quorum=#{Shellwords.escape(opts['tolerate-quorum'])}"] +
          ["--network=#{Shellwords.escape(opts['network'])}"] +
          (opts['tolerate-edges'] ? ['--tolerate-edges'] : [])
        )
      end
      raise 'Amount is required (in ZLD) as the third argument' if mine[2].nil?
      amount = amount(mine[2].strip)
      details = mine[3] || '-'
      taxes(id, opts)
      txn = @wallets.acq(id, exclusive: true) do |from|
        pay(from, invoice, amount, details, opts)
      end
      return if opts['skip-propagate']
      require_relative 'propagate'
      Propagate.new(wallets: @wallets, log: @log).run(['propagate', id.to_s])
      txn
    end

    private

    def amount(txt)
      return Amount.new(zents: txt.gsub(/z$/, '').to_i) if txt.end_with?('z')
      return Amount.new(zld: txt.gsub(/Z$/, '').to_f) if txt.end_with?('Z')
      Amount.new(zld: txt.to_f)
    end

    def taxes(id, opts)
      debt = @wallets.acq(id) do |wallet|
        raise "Wallet #{id} doesn't exist, do 'zold pull' first" unless wallet.exists?
        Tax.new(wallet).in_debt? && !opts['dont-pay-taxes']
      end
      return unless debt || opts['pay-taxes-anyway']
      require_relative 'taxes'
      Taxes.new(wallets: @wallets, remotes: @remotes, log: @log).run(
        [
          'taxes',
          'pay',
          "--private-key=#{Shellwords.escape(opts['private-key'])}",
          opts['pay-taxes-anyway'] ? '--pay-anyway' : '',
          opts['ignore-score-weakness'] ? '--ignore-score-weakness' : '',
          id.to_s,
          "--keygap=#{Shellwords.escape(opts['keygap'])}"
        ].reject(&:empty?)
      )
    end

    def pay(from, invoice, amount, details, opts)
      unless opts.force?
        raise 'The amount can\'t be zero' if amount.zero?
        raise "The amount can't be negative: #{amount}" if amount.negative?
        if !from.root? && from.balance < amount
          raise "There is not enough funds in #{from} to send #{amount}, only #{from.balance} left; \
the difference is #{(amount - from.balance).to_i} zents"
        end
      end
      pem = IO.read(opts['private-key'])
      unless opts['keygap'].empty?
        pem = pem.sub('*' * opts['keygap'].length, opts['keygap'])
        @log.debug("Keygap \"#{'*' * opts['keygap'].length}\" injected into the RSA private key")
      end
      key = Zold::Key.new(text: pem)
      from.refurbish
      txn = from.sub(amount, invoice, key, details, time: Txn.parse_time(opts['time']))
      @log.debug("#{amount} sent from #{from} to #{txn.bnf}: #{details}")
      @log.debug("Don't forget to do 'zold push #{from}'")
      @log.info(txn.id)
      tax = Tax.new(from)
      @log.info("The tax debt of #{from.mnemo} is #{tax.debt} \
(#{tax.in_debt? ? 'too high' : 'still acceptable'})")
      txn
    end
  end
end
