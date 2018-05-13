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
    def initialize(wallets:, pubkey:, log: Log::Quiet.new)
      @wallets = wallets
      @pubkey = pubkey
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true) do |o|
        o.banner = "Usage: zold create [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      create(opts.arguments.empty? ? Id.new : Id.new(opts.arguments[0]), opts)
    end

    def create(id, _)
      wallet = @wallets.find(id)
      wallet.init(id, @pubkey)
      @log.info(wallet.id)
      @log.debug("Wallet #{Rainbow(wallet).green} \
created at #{@wallets.path}")
      wallet
    end
  end
end
