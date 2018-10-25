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

require 'concurrent'
require 'tempfile'
require_relative 'emission'
require_relative '../log'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'

# The entrance thav validate the incoming wallet first.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The safe entrance
  class SafeEntrance
    def initialize(entrance, network: 'test')
      raise 'Entrance can\'t be nil' if entrance.nil?
      @entrance = entrance
      raise 'Network can\'t be nil' if network.nil?
      @network = network
    end

    def start
      @entrance.start { yield(self) }
    end

    def to_json
      @entrance.to_json
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      raise 'Body can\'t be nil' if body.nil?
      Tempfile.open(['', Wallet::EXTENSION]) do |f|
        IO.write(f, body)
        wallet = Wallet.new(f.path)
        wallet.refurbish
        unless wallet.protocol == Zold::PROTOCOL
          raise "Protocol mismatch, #{wallet.id} is in '#{wallet.protocol}', we are in '#{Zold::PROTOCOL}'"
        end
        unless wallet.network == @network
          raise "Network name mismatch, #{wallet.id} is in '#{wallet.network}', we are in '#{@network}'"
        end
        balance = wallet.balance
        if balance.negative? && !wallet.root?
          raise "The balance #{balance} of #{wallet.id} is negative and it's not a root wallet"
        end
        Emission.new(wallet).check
        tax = Tax.new(wallet)
        if tax.in_debt?
          raise "Taxes are not paid, can't accept the wallet; the debt is #{tax.debt} (#{tax.debt.to_i} zents)"
        end
        @entrance.push(id, body)
      end
    end
  end
end
