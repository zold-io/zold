# frozen_string_literal: true

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

require 'slop'
require 'json'
require 'rainbow'
require_relative 'args'
require_relative 'pay'
require_relative '../log'
require_relative '../json_page'
require_relative '../score'
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
    def initialize(wallets:, remotes:, log: Log::Quiet.new)
      @wallets = wallets
      @remotes = remotes
      @log = log
    end

    def run(args = [])
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
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak',
          default: false
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      command = mine[0]
      case command
      when 'show'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.find(Id.new(id)) do |w|
            show(w, opts)
          end
        end
      when 'debt'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.find(Id.new(id)) do |w|
            debt(w, opts)
          end
        end
      when 'pay'
        raise 'At least one wallet ID is required' unless mine[1]
        mine[1..-1].each do |id|
          @wallets.find(Id.new(id)) do |w|
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
      debt = tax.debt
      @log.debug("The current debt is #{debt} (#{debt.to_i} zents)")
      unless tax.in_debt?
        @log.debug("No need to pay taxes yet, until the debt is less than #{Tax::TRIAL} (#{Tax::TRIAL.to_i} zents)")
        return
      end
      top = top_scores(opts)
      while debt > Tax::TRIAL
        raise 'No acceptable remote nodes, try later' if top.empty?
        best = top.shift
        txn = tax.pay(Zold::Key.new(file: opts['private-key']), best)
        debt += txn.amount
        @log.info("#{txn.amount} of taxes paid to #{txn.bnf}, #{debt} left to pay")
      end
      @log.info('The wallet is in good standing, all taxes paid')
    end

    def debt(wallet, _)
      raise 'The wallet is absent' unless wallet.exists?
      tax = Tax.new(wallet)
      @log.info(tax.debt)
    end

    def show(_, _)
      raise 'Not implemented yet'
    end

    def top_scores(opts)
      best = []
      @remotes.iterate(@log) do |r|
        uri = '/'
        res = r.http(uri).get
        r.assert_code(200, res)
        json = JsonPage.new(res.body, uri).to_hash
        score = Score.parse_json(json['score'])
        r.assert_valid_score(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        r.assert_score_value(score, Tax::EXACT_SCORE)
        @log.info("#{r}: #{Rainbow(score.value).green}")
        best << score
      end
      best.sort_by(&:value).reverse
    end
  end
end
