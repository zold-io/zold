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
require 'json'
require 'rainbow'
require 'zold/score'
require_relative 'thread_badge'
require_relative 'args'
require_relative 'pay'
require_relative '../log'
require_relative '../json_page'
require_relative '../id'
require_relative '../tax'
require_relative '../http'

# Zold module.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Taxes command.
  #
  # The user pays taxes for his/her wallet by running 'zold taxes pay'. As
  # the White Paper explains (find it at http://papers.zold.io), each wallet
  # has to pay certain amount of taxes in order to be accepted by any node
  # in the network. Of course, a node may make a decision to accept and
  # store any wallet, even if taxes are not paid, but the majority of
  # nodes will obey the rules and will reject wallets that haven't paid
  # enough taxes.
  #
  # Taxes are paid from wallet to wallet, not from clients to nodes. A wallet
  # just selects the most suitable wallet to transfer taxes to and sends
  # the payment. More details you can find in the White Paper.
  class Taxes
    prepend ThreadBadge

    def initialize(wallets:, remotes:, log: Log::NULL)
      @wallets = wallets
      @remotes = remotes
      @log = log
    end

    def run(args = [])
      @log.debug("Taxes.run(#{args.join(' ')})")
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold taxes command [options]
Available commands:
    #{Rainbow('taxes pay').green} wallet
      Pay taxes for the given wallet
    #{Rainbow('taxes show').green}
      Show taxes status for the given wallet
    #{Rainbow('taxes debt').green}
      Show current debt
Available options:"
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          require: true,
          default: '~/.ssh/id_rsa'
        o.bool '--pay-anyway',
          'Pay taxes anyway, even if the wallet is not in debt',
          default: false
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak',
          default: false
        o.bool '--ignore-score-size',
          'Don\'t complain when their score is too small',
          default: false
        o.string '--keygap',
          'Keygap, if the private RSA key is not complete',
          default: ''
        o.bool '--ignore-nodes-absence',
          'Don\'t complain if there are not enough nodes in the network to pay taxes',
          default: false
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      command = mine[0]
      case command
      when 'show'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.acq(Id.new(id)) do |w|
            show(w, opts)
          end
        end
      when 'debt'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.acq(Id.new(id)) do |w|
            debt(w, opts)
          end
        end
      when 'pay'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.acq(Id.new(id), exclusive: true) do |w|
            pay(w, opts)
          end
        end
      else
        @log.info(opts.to_s)
      end
    end

    private

    def pay(wallet, opts)
      raise 'The wallet is absent' unless wallet.exists?
      tax = Tax.new(wallet)
      debt = total = tax.debt
      @log.info("The current debt of #{wallet.mnemo} is #{debt} (#{debt.to_i} zents), \
the balance is #{wallet.balance}: #{tax.to_text}")
      unless tax.in_debt? || opts['pay-anyway']
        @log.debug("No need to pay taxes yet, while the debt is less than #{Tax::TRIAL} (#{Tax::TRIAL.to_i} zents)")
        return
      end
      top = top_scores(opts)
      everybody = top.dup
      paid = 0
      while debt > Tax::TRIAL
        if top.empty?
          msg = [
            "There were #{everybody.count} remote nodes as tax collecting candidates;",
            "#{paid} payments have been made;",
            "there was not enough score power to pay the total debt of #{total} for #{wallet.id};",
            "the residual amount to pay is #{debt} (trial amount is #{Tax::TRIAL});",
            "the formula ingredients are #{tax.to_text}"
          ].join(' ')
          raise msg unless opts['ignore-nodes-absence']
          @log.info(msg)
          break
        end
        best = top.shift
        if tax.exists?(tax.details(best))
          @log.debug("The score has already been taxed: #{best}")
          next
        end
        pem = IO.read(opts['private-key'])
        unless opts['keygap'].empty?
          pem = pem.sub('*' * opts['keygap'].length, opts['keygap'])
          @log.debug("Keygap \"#{'*' * opts['keygap'].length}\" injected into the RSA private key")
        end
        txn = tax.pay(Zold::Key.new(text: pem), best)
        debt += txn.amount
        paid += 1
        @log.info("#{txn.amount * -1} of taxes paid from #{wallet.id} to #{txn.bnf} \
(payment no.#{paid}, txn ##{txn.id}/#{wallet.txns.count}), #{debt} left to pay")
      end
      @log.info('The wallet is in good standing, all taxes paid') unless tax.in_debt?
    end

    def debt(wallet, _)
      raise 'The wallet is absent' unless wallet.exists?
      tax = Tax.new(wallet)
      @log.info(tax.debt)
      @log.debug(tax.to_text)
      @log.debug('Read the White Paper for more details: https://papers.zold.io/wp.pdf')
    end

    def show(wallet, _)
      raise 'The wallet is absent' unless wallet.exists?
      tax = Tax.new(wallet)
      @log.info(tax.to_text)
      @log.info('Read the White Paper for more details: https://papers.zold.io/wp.pdf')
    end

    def top_scores(opts)
      best = []
      @remotes.iterate(@log) do |r|
        @log.debug("Testing #{r}...")
        uri = '/'
        res = r.http(uri).get
        r.assert_code(200, res)
        json = JsonPage.new(res.body, uri).to_hash
        score = Score.parse_json(json['score'])
        r.assert_valid_score(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        r.assert_score_value(score, Tax::EXACT_SCORE) unless opts['ignore-score-size']
        @log.info("#{r}: #{Rainbow(score.value).green} to #{score.invoice}")
        best << score
      end
      best.sort_by(&:value).reverse
    end
  end
end
