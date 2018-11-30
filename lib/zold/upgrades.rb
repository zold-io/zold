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

require_relative 'log'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory, opts, log: Log::VERBOSE)
      raise 'network can\'t be nil' if opts[:network].nil?
      @version = version
      @directory = directory
      @log = log
      @opts = opts
    end

    def run
      Dir.glob("#{@directory}/*.rb").select { |f| f =~ /^(\d+)\.rb$/ }.sort.each do |script|
        @version.apply(script)
      end

      command = @opts[:command]
      require_relative '../../upgrades/2'
      Zold::UpgradeTo2.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/protocol_up'
      Zold::ProtocolUp.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/rename_foreign_wallets'
      Zold::RenameForeignWallets.new(Dir.pwd, @opts[:network], @log).exec
      return unless command == 'node'
      require_relative '../../upgrades/move_wallets_into_tree'
      Zold::MoveWalletsIntoTree.new(Dir.pwd, @log).exec
    end
  end
end
