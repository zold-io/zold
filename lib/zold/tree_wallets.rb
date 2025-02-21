# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT
require 'pathname'
require_relative 'id'
require_relative 'wallet'
require_relative 'dir_items'

# The local collection of wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Collection of local wallets, in a tree of directories
  class TreeWallets
    def initialize(dir)
      @dir = dir
    end

    def to_s
      path
    end

    def path
      FileUtils.mkdir_p(@dir)
      File.expand_path(@dir)
    end

    # Returns the list of their IDs (as plain text)
    def all
      DirItems.new(path).fetch.select do |f|
        next unless f.end_with?(Wallet::EXT)
        basename = File.basename(f, Wallet::EXT)
        file = File.join(path, f)
        File.file?(file) &&
          !File.directory?(file) &&
          basename =~ /^[0-9a-fA-F]{16}$/ &&
          Id.new(basename).to_s == basename
      end.map { |w| Id.new(File.basename(w, Wallet::EXT)) }
    end

    def acq(id, exclusive: false)
      raise 'The flag can\'t be nil' if exclusive.nil?
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      yield Wallet.new(
        File.join(path, (id.to_s.split('', 5).take(4) + [id.to_s]).join('/') + Wallet::EXT)
      )
    end

    def count
      `find #{@dir} -name "*.z" | wc -l`.strip.to_i
    end
  end
end
