# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT
require 'pathname'
require_relative 'dir_items'
require_relative 'id'
require_relative 'wallet'

# The local collection of wallets.
#
# This class is not thread-safe!
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Collection of local wallets
  class Wallets
    def initialize(dir)
      @dir = dir
    end

    # @todo #70:30min Let's make it smarter. Instead of returning
    #  the full path let's subtract the prefix from it if it's equal
    #  to the current directory in Dir.pwd.
    def to_s
      Pathname.new(File.expand_path(@dir)).relative_path_from(Pathname.new(File.expand_path(Dir.pwd))).to_s
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
      raise(RuntimeError, 'The flag can\'t be nil') if exclusive.nil?
      raise(RuntimeError, 'Id can\'t be nil') if id.nil?
      raise(RuntimeError, "Id must be of type Id, #{id.class.name} instead") unless id.is_a?(Id)
      yield(Wallet.new(File.join(path, id.to_s + Wallet::EXT)))
    end

    def count
      Zold::DirItems.new(@dir)
        .fetch(recursive: false)
        .count { |f| f.end_with?(Wallet::EXT) }
    end
  end
end
