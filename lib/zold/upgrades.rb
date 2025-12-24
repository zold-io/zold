# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory, opts, log: Loog::NULL)
      raise 'network can\'t be nil' if opts[:network].nil?
      @version = version
      @directory = directory
      @log = log
      @opts = opts
    end

    def run
      Dir.glob("#{@directory}/*.rb").grep(/^(\d+)\.rb$/).sort.each do |script|
        @version.apply(script)
      end
      command = @opts[:command]
      require_relative '../../upgrades/delete_banned_wallets'
      DeleteBannedWallets.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/2'
      UpgradeTo2.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/protocol_up'
      ProtocolUp.new(Dir.pwd, @log).exec
      require_relative '../../upgrades/rename_foreign_wallets'
      RenameForeignWallets.new(Dir.pwd, @opts[:network], @log).exec
      return unless command == 'node'
      require_relative '../../upgrades/move_wallets_into_tree'
      MoveWalletsIntoTree.new(Dir.pwd, @log).exec
    end
  end
end
