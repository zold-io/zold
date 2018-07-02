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
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../hungry_wallets'
require_relative '../commands/clean'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'

# The entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class Entrance
    def initialize(wallets, remotes, copies, address, log: Log::Quiet.new)
      raise 'Wallets can\'t be nil' if wallets.nil?
      raise 'Wallets must be of type HungryWallets' unless wallets.is_a?(HungryWallets) || wallets.is_a?(Wallets)
      @wallets = wallets
      raise 'Remotes can\'t be nil' if remotes.nil?
      raise "Remotes must be of type Remotes: #{remotes.class.name}" unless remotes.is_a?(Remotes)
      @remotes = remotes
      raise 'Copies can\'t be nil' if copies.nil?
      @copies = copies
      raise 'Address can\'t be nil' if address.nil?
      @address = address
      raise 'Log can\'t be nil' if log.nil?
      @log = log
      @history = []
      @mutex = Mutex.new
    end

    def start
      yield(self)
    end

    def to_json
      {
        history: @history.join(', ')
      }
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      raise 'Body can\'t be nil' if body.nil?
      start = Time.now
      copies = Copies.new(File.join(@copies, id.to_s))
      localhost = '0.0.0.0'
      copies.add(body, localhost, Remotes::PORT, 0)
      unless @remotes.all.empty?
        Fetch.new(
          wallets: @wallets, remotes: @remotes, copies: copies.root, log: @log
        ).run(['fetch', id.to_s, "--ignore-node=#{@address}"])
      end
      modified = Merge.new(
        wallets: @wallets, copies: copies.root, log: @log
      ).run(['merge', id.to_s, '--no-baseline'])
      Clean.new(wallets: @wallets, copies: copies.root, log: @log).run(['clean', id.to_s])
      copies.remove(localhost, Remotes::PORT)
      sec = (Time.now - start).round(2)
      if modified.empty?
        @log.info("Accepted #{id} in #{sec}s and not modified anything")
      else
        @log.info("Accepted #{id} in #{sec}s and modified #{modified.join(', ')}")
      end
      @mutex.synchronize do
        @history.shift if @history.length > 16
        wallet = @wallets.find(id)
        @history << "#{id}/#{sec}/#{modified.count}/#{wallet.balance.to_zld}/#{wallet.txns.count}t"
      end
      modified
    end
  end
end
