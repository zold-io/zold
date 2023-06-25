# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy, Inc.
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
require_relative '../log'

# REMOVe command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # REMOVE command
  class Remove
    prepend ThreadBadge

    def initialize(wallets:, log: Log::NULL)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold remove [ID...] [options]
Available options:"
        o.bool '--force',
          'Don\'t report any errors if the wallet doesn\'t exist',
          default: false
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      (mine.empty? ? @wallets.all : mine.map { |i| Id.new(i) }).each do |id|
        remove(id, opts)
      end
    end

    def remove(id, opts)
      @wallets.acq(id, exclusive: true) do |w|
        if w.exists?
          File.delete(w.path)
        else
          raise "Wallet #{id} doesn't exist in #{w.path}" unless opts['force']
          @log.info("Wallet #{id} file not found in #{w.path}")
        end
      end
      @log.info("Wallet #{id} removed")
    end
  end
end
