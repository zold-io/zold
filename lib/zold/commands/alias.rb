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

require 'slop'
require 'rainbow'
require_relative 'thread_badge'
require_relative 'args'
require_relative '../log'

module Zold
  # Command to set an alias for wallet ID
  class Alias
    prepend ThreadBadge

    def initialize(wallets:, log: Log::NULL)
      @wallets = wallets
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold alias [args]
    #{Rainbow('alias set <wallet> <alias>').green}
      Make wallet known under an alias.
    #{Rainbow('alias remove <alias>').green}
      Remove an alias.
    #{Rainbow('alias show <alias>').green}
      Show where the alias is pointing to.
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      command = mine[0]
      raise "A command is required, try 'zold alias --help'" unless command

      # @todo #279:30min Implement command handling. As in other commands,
      #  there should be case/when command/end loop and commands should be
      #  implemented as methods.
      raise NotImplementedError, 'This is not yet implemented'
    end
  end
end
