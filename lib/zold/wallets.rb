# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT
require 'pathname'
require_relative 'id'
require_relative 'wallet'
require_relative 'dir_items'

# The local collection of wallets.
#
# This class is not thread-safe!
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Collection of local wallets
  class Wallets
    def initialize(dir)
      @dir = dir
    end

    def to_s
      mine = Pathname.new(File.expand_path(@dir))
      home = Pathname.new(File.expand_path(Dir.pwd))
      if mine.to_s.index(home.to_s)
        mine = mine.to_s[home.to_s.length, mine.to_s.length]
        mine = Pathname.new(mine)
      end
    end

    def path
      FileUtils.mkdir_p(@dir)
      File.expand_path(@dir)
    end

    # This wallet exists?
    def exists?(id)
      File.exist?(File.join(path, id.to_s + Wallet::EXT))
    end

    # Returns the list of their IDs (as plain text)
    def all
      DirItems.new(path).fetch(recursive: false).select do |f|
        file = File.join(@dir, f)
        basename = File.basename(f, Wallet::EXT)
        File.file?(file) &&
          !File.directory?(file) &&
          basename =~ /^[0-9a-fA-F]{16}$/ &&
          Id.new(basename).to_s == basename
      end.map { |w| Id.new(File.basename(w, Wallet::EXT)) }
    end

    def acq(id, exclusive: false)
      raise 'The flag can\'t be nil' if exclusive.nil?
      raise 'Id can\'t be nil' if id.nil?
      raise "Id must be of type Id, #{id.class.name} instead" unless id.is_a?(Id)
      yield Wallet.new(File.join(path, id.to_s + Wallet::EXT))
    end

    def count
      Zold::DirItems.new(@dir)
        .fetch(recursive: false)
        .select { |f| f.end_with?(Wallet::EXT) }
        .count
    end
  end
end
