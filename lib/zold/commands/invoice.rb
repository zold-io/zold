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
require_relative 'args'
require_relative '../log'
require_relative '../prefixes'

# INVOICE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Generate invoice
  class Invoice
    def initialize(wallets:, remotes:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold invoice ID [options]
Where:
    'ID' is the wallet ID of the money receiver
Available options:"
        o.integer '--length',
          'The length of the invoice prefix (default: 8)',
          default: 8
        o.string '--network',
          'The name of the network we work in',
          default: 'test'
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'Receiver wallet ID is required' if mine[0].nil?
      id = Zold::Id.new(mine[0])
      invoice(id, opts)
    end

    private

    def invoice(id, opts)
      unless @wallets.find(id, &:exists?)
        require_relative 'pull'
        Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
          ['pull', id.to_s, "--network=#{opts['network']}"]
        )
      end
      inv = @wallets.find(id) do |wallet|
        "#{Prefixes.new(wallet).create(opts[:length])}@#{wallet.id}"
      end
      @log.info(inv)
      inv
    end
  end
end
