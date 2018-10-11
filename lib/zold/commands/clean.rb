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

require 'uri'
require 'json'
require 'time'
require 'slop'
require 'rainbow'
require_relative 'args'
require_relative '../age'
require_relative '../size'
require_relative '../log'
require_relative '../http'
require_relative '../score'
require_relative '../copies'

# CLEAN command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # CLEAN command
  class Clean
    def initialize(wallets:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold clean [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      mine = @wallets.all if mine.empty?
      mine.map { |i| Id.new(i) }.each do |id|
        clean(Copies.new(File.join(@copies, id), log: @log), opts)
      end
    end

    def clean(cps, _)
      deleted = cps.clean
      @log.debug("#{deleted} expired local copies removed for #{cps}, #{cps.all.count} left:")
      cps.all.each do |c|
        wallet = Wallet.new(c[:path])
        @log.debug("  #{c[:name]}: #{c[:score]} #{wallet.balance}/#{wallet.txns.count}t/\
#{wallet.digest[0, 6]}/#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}")
      end
    end
  end
end
