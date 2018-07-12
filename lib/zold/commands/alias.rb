require 'slop'
require 'rainbow'
require_relative 'args'
require_relative '../log'

module Zold
  # Command to set an alias for wallet ID
  class Alias
    def initialize(wallets:, log: Log::Quiet.new)
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
