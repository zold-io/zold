# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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
require_relative 'thread_badge'
require_relative 'args'
require_relative '../wallet'
require_relative '../log'
require_relative '../id'

# CREATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Create command
  class Create
    prepend ThreadBadge

    def initialize(wallets:, remotes:, log: Log::NULL)
      @wallets = wallets
      @remotes = remotes
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold create [options]
Available options:"
        o.string '--public-key',
          'The location of RSA public key (default: ~/.ssh/id_rsa.pub)',
          require: true,
          default: File.expand_path('~/.ssh/id_rsa.pub')
        o.bool '--skip-test',
          'Don\'t check whether this wallet ID is available',
          default: false
        o.string '--network',
          "The name of the network (default: #{Wallet::MAINET}",
          require: true,
          default: Wallet::MAINET
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      create(mine.empty? ? create_id(opts) : Id.new(mine[0]), opts)
    end

    private

    def create_id(opts)
      loop do
        id = Id.new
        return id if opts['skip-test']
        found = @wallets.exists?(id)
        if found
          @log.debug("Wallet ID #{id} already exists locally, will try another one...")
          next
        end
        @remotes.iterate(@log) do |r|
          head = r.http("/wallet/#{id}/digest").get
          found = true if head.status == 200
        end
        return id unless found
        @log.info("Wallet ID #{id} is already occupied, will try another one...")
      end
    end

    def create(id, opts)
      key = Zold::Key.new(file: opts['public-key'])
      @wallets.acq(id, exclusive: true) do |wallet|
        raise "Wallet #{id} already exists" if wallet.exists?
        wallet.init(id, key, network: opts['network'])
        @log.debug("Wallet #{Rainbow(wallet).green} created at #{@wallets.path}")
      end
      @log.info(id)
      id
    end
  end
end
