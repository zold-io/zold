# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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

require 'shellwords'
require_relative '../routines'
require_relative '../../log'
require_relative '../../id'
require_relative '../../copies'
require_relative '../push'

# Spread random wallets to the network.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
class Zold::Routines::Spread
  def initialize(opts, wallets, remotes, copies, log: Log::NULL)
    @opts = opts
    @wallets = wallets
    @remotes = remotes
    @copies = copies
    @log = log
  end

  def exec(_ = 0)
    sleep(60) unless @opts['routine-immediately']
    @wallets.all.sample(100).each do |id|
      next if Zold::Copies.new(File.join(@copies, id)).all.count < 2
      Zold::Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
        ['push', "--network=#{Shellwords.escape(@opts['network'])}", id.to_s]
      )
    end
  end
end
