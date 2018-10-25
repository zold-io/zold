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

require 'tempfile'
require_relative '../log'
require_relative '../size'
require_relative '../wallet'

# The entrance that ignores duplicates.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The safe entrance
  class NoDupEntrance
    def initialize(entrance, wallets, log: Log::Quiet.new)
      raise 'Entrance can\'t be nil' if entrance.nil?
      @entrance = entrance
      raise 'Wallets can\'t be nil' if wallets.nil?
      @wallets = wallets
      raise 'Log can\'t be nil' if log.nil?
      @log = log
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
        after = IO.read(wallet.path)
        before = @wallets.find(id) do |w|
          w.exists? ? IO.read(w.path).to_s : ''
        end
        if before == after
          @log.info(
            "Duplicate of #{id}/#{wallet.digest[0, 6]}/#{Size.new(after.length)}/#{wallet.txns.count}t ignored"
          )
          return []
        end
        @log.info(
          "New content for #{id} arrived, #{Size.new(before.length)} before and #{Size.new(after.length)} after"
        )
        @entrance.push(id, body)
      end
    end
  end
end
