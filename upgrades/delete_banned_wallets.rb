# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
  # Delete wallets which are in the banned-wallets.csv file
  class DeleteBannedWallets
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      banned = IO.read(File.join(__dir__, '../resources/banned-wallets.csv'))
      DirItems.new(@home).fetch.each do |path|
        name = File.basename(path)
        next unless name =~ /^[a-f0-9]{16}#{Wallet::EXT}$/
        id = name[0..15]
        next unless banned.include?("\"#{id}\"")
        path = File.join(@home, path)
        File.rename(path, path + '-banned')
        @log.info("Wallet file #{path} renamed, since wallet #{id} is banned")
      end
    end
  end
end
