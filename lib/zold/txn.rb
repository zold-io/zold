# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative 'id'
require_relative 'hexnum'
require_relative 'amount'
require_relative 'signature'

# The transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # A single transaction
  class Txn
    # When can't parse them.
    class CantParse < StandardError; end

    # Regular expression for details
    RE_DETAILS = '[a-zA-Z0-9 @\!\?\*_\-\.:,\'/]+'
    private_constant :RE_DETAILS

    # Regular expression for prefix
    RE_PREFIX = '[a-zA-Z0-9]+'
    private_constant :RE_PREFIX

    # To validate the prefix
    REGEX_PREFIX = Regexp.new("^#{RE_PREFIX}$")
    private_constant :REGEX_PREFIX

    # To validate details
    REGEX_DETAILS = Regexp.new("^#{RE_DETAILS}$")
    private_constant :REGEX_DETAILS

    attr_accessor :amount, :bnf, :sign
    attr_reader :id, :date, :prefix, :details

    # Make a new object of this class (you must read the White Paper
    # in order to understand this class).
    #
    # +id+:: is the ID of the transaction, an integer
    # +date+:: is the date/time of the transaction
    # +amount+:: is the amount, an instance of class +Amount+
    # +prefix+:: is the prefix from the Invoice (read the WP)
    # +bnf+:: is the wallet ID of the paying or receiving wallet
    # +details+:: is the details, in plain text
    def initialize(id, date, amount, prefix, bnf, details)
      raise 'The ID can\'t be NIL' if id.nil?
      raise "ID of transaction can't be negative: #{id}" if id < 1
      @id = id
      raise 'The time can\'t be NIL' if date.nil?
      raise 'Time have to be of type Time' unless date.is_a?(Time)
      raise "Time can't be in the future: #{date.utc.iso8601}" if date > Time.now
      @date = date
      raise 'The amount can\'t be NIL' if amount.nil?
      raise 'The amount has to be of type Amount' unless amount.is_a?(Amount)
      raise 'The amount can\'t be zero' if amount.zero?
      @amount = amount
      raise 'The bnf can\'t be NIL' if bnf.nil?
      raise 'The bnf has to be of type Id' unless bnf.is_a?(Id)
      @bnf = bnf
      raise 'Prefix can\'t be NIL' if prefix.nil?
      raise "Prefix is too short: #{prefix.inspect}" if prefix.length < 8
      raise "Prefix is too long: #{prefix.inspect}" if prefix.length > 32
      raise "Prefix is wrong: #{prefix.inspect} (#{RE_PREFIX})" unless REGEX_PREFIX.match?(prefix)
      @prefix = prefix
      raise 'Details can\'t be NIL' if details.nil?
      raise 'Details can\'t be empty' if details.empty?
      raise "Details are too long: #{details.inspect}" if details.length > 512
      raise "Wrong details #{details.inspect} (#{RE_DETAILS})" unless REGEX_DETAILS.match?(details)
      @details = details
    end

    def ==(other)
      id == other.id && date == other.date && amount == other.amount &&
        prefix == other.prefix && bnf == other.bnf &&
        details == other.details && sign == other.sign
    end

    def <=>(other)
      raise 'Can only compare with Txn' unless other.is_a?(Txn)
      [date, amount * -1, id, bnf] <=> [other.date, other.amount * -1, other.id, other.bnf]
    end

    def to_s
      [
        Hexnum.new(@id, 4).to_s,
        @date.utc.iso8601,
        Hexnum.new(@amount.to_i, 16),
        @prefix,
        @bnf,
        @details,
        @sign
      ].join(';')
    end

    def to_json
      {
        id: @id,
        date: @date.utc.iso8601,
        amount: @amount.to_i,
        prefix: @prefix,
        bnf: @bnf.to_s,
        details: @details,
        sign: @sign
      }
    end

    def to_text
      start = @amount.negative? ? "##{@id}" : "(#{@id})"
      "#{start} #{@date.utc.iso8601} #{@amount} #{@bnf} #{@details}"
    end

    def inverse(bnf)
      raise 'You can\'t reverse a positive transaction' unless amount.negative?
      t = clone
      t.amount = amount * -1
      t.bnf = bnf
      t.sign = ''
      t
    end

    # Sign the transaction and add RSA signature to it
    # +pvt+:: The private RSA key of the paying wallet
    # +id+:: Paying wallet ID
    def signed(pvt, id)
      t = clone
      t.sign = Signature.new.sign(pvt, id, self)
      t
    end

    # Pattern to match the transaction from text
    PTN = Regexp.new(
      [
        '^',
        [
          '(?<id>[0-9a-f]{4})',
          '(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          '(?<amount>[0-9a-f]{16})',
          "(?<prefix>#{RE_PREFIX})",
          '(?<bnf>[0-9a-f]{16})',
          "(?<details>#{RE_DETAILS})",
          '(?<sign>[A-Za-z0-9+/]+={0,3})?'
        ].join(';'),
        '$'
      ].join
    )
    private_constant :PTN

    def self.parse(line, idx = 0)
      clean = line.strip
      parts = PTN.match(clean)
      raise CantParse, "Invalid line ##{idx}: #{line.inspect} (doesn't match #{PTN})" unless parts
      txn = Txn.new(
        Hexnum.parse(parts[:id]).to_i,
        parse_time(parts[:date]),
        Amount.new(zents: Hexnum.parse(parts[:amount]).to_i),
        parts[:prefix],
        Id.new(parts[:bnf]),
        parts[:details]
      )
      txn.sign = parts[:sign] || ''
      txn
    end

    # When time can't be parsed.
    class CantParseTime < StandardError; end

    ISO8601 = Regexp.new(
      [
        '^',
        [
          '(?<year>\d{4})',
          '-(?<month>\d{2})',
          '-(?<day>\d{2})',
          'T(?<hours>\d{2})',
          ':(?<minutes>\d{2})',
          ':(?<seconds>\d{2})Z'
        ].join
      ].join
    )
    private_constant :ISO8601

    def self.parse_time(iso)
      parts = ISO8601.match(iso)
      raise CantParseTime, "Invalid ISO 8601 date \"#{iso}\"" if parts.nil?
      Time.gm(
        parts[:year].to_i, parts[:month].to_i, parts[:day].to_i,
        parts[:hours].to_i, parts[:minutes].to_i, parts[:seconds].to_i
      )
    end
  end
end
