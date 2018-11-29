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

require 'rainbow'
require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Rename wallets that belong to another network
  class RenameForeignWallets
    def initialize(home, network, log)
      @home = home
      @network = network
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless path =~ /^[a-f0-9]{16}#{Wallet::EXT}$/
        f = File.join(@home, path)
        wallet = Wallet.new(f)
        next if wallet.network == @network
        @log.info("Wallet #{wallet.id} #{Rainbow(renamed).red}, \
since it's in \"#{wallet.network}\", while we are in \"#{@network}\" network")
        File.rename(f, f + '-old')
      end
    end
  end
end
