# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'csv'
require 'securerandom'

# The ID of the wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Id of the wallet
  class Id
    # Pattern to match the ID
    PTN = Regexp.new('^[0-9a-fA-F]{16}$')
    private_constant :PTN

    # Returns a list of banned IDs, as strings
    BANNED = CSV.read(File.join(__dir__, '../../resources/banned-wallets.csv')).map { |r| r[0] }

    def self.generate_id
      loop do
        id = SecureRandom.hex(8)
        next if Id::BANNED.include?(id)
        return id
      end
    end

    def initialize(id = Id.generate_id)
      raise "Invalid wallet ID type: #{id.class.name}" unless id.is_a?(String)
      raise "Invalid wallet ID: #{id}" unless PTN.match?(id)
      @id = Integer("0x#{id}", 16)
    end

    # The ID of the root wallet.
    ROOT = Id.new('0000000000000000')

    def root?
      to_s == ROOT.to_s
    end

    def eql?(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s == other.to_s
    end

    def hash
      to_s.hash
    end

    def ==(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s == other.to_s
    end

    def <=>(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s <=> other.to_s
    end

    def to_str
      to_s
    end

    def to_s
      format('%016x', @id)
    end
  end
end
