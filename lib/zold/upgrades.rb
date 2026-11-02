# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory, opts, log: Loog::NULL)
      raise(RuntimeError, 'network can\'t be nil') if opts[:network].nil?
      @version = version
      @directory = directory
      @log = log
      @opts = opts
    end

    def run
      versions = Dir.glob("#{@directory}/*.rb").map { |f| File.basename(f, '.rb') }.grep(/^\d+(\.\d+)*$/)
      versions.sort_by { |v| ::Gem::Version.new(v) }.each do |v|
        @version.apply(v) { load(File.join(@directory, "#{v}.rb")) }
      end
      require_relative('../../upgrades/delete_banned_wallets')
      DeleteBannedWallets.new(Dir.pwd, @log).exec
      require_relative('../../upgrades/2')
      UpgradeTo2.new(Dir.pwd, @log).exec
      require_relative('../../upgrades/protocol_up')
      ProtocolUp.new(Dir.pwd, @log).exec
      require_relative('../../upgrades/rename_foreign_wallets')
      RenameForeignWallets.new(Dir.pwd, @opts[:network], @log).exec
      return unless @opts[:command] == 'node'
      require_relative('../../upgrades/move_wallets_into_tree')
      MoveWalletsIntoTree.new(Dir.pwd, @log).exec
    end
  end
end
