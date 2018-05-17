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

require 'digest'
require 'time'
require_relative 'remotes'

# The score.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Score
  class Score
    STRENGTH = 6
    attr_reader :time, :host, :port, :invoice, :strength
    # time: UTC ISO 8601 string
    def initialize(time, host, port, invoice, suffixes = [], strength: STRENGTH)
      raise "Invalid host name: #{host}" unless host =~ /^[a-z0-9\.-]+$/
      raise 'Time must be of type Time' unless time.is_a?(Time)
      raise 'Port must be of type Integer' unless port.is_a?(Integer)
      raise "Invalid TCP port: #{port}" if port <= 0 || port > 65_535
      raise "Invoice '#{invoice}' has wrong format" unless invoice =~ /^[a-zA-Z0-9]{8,32}@[a-f0-9]{16}$/
      @time = time
      @host = host
      @port = port
      @invoice = invoice
      @suffixes = suffixes
      @strength = strength
    end

    ZERO = Score.new(
      Time.now, 'localhost',
      Remotes::PORT, 'NOPREFIX@ffffffffffffffff'
    )

    def self.parse_json(json)
      raise "Time in JSON is broken: #{json}" unless json['time'] =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
      raise "Host is wrong: #{json}" unless json['host'] =~ /^[0-9a-z\.\-]+$/
      raise "Port is wrong: #{json}" unless json['port'].is_a?(Integer)
      raise "Invoice is wrong: #{json}" unless json['invoice'] =~ /^[a-zA-Z0-9]{8,32}@[a-f0-9]{16}$/
      raise "Suffixes not array: #{json}" unless json['suffixes'].is_a?(Array)
      Score.new(
        Time.parse(json['time']), json['host'],
        json['port'], json['invoice'], json['suffixes'],
        strength: json['strength']
      )
    end

    def self.parse(text, strength: STRENGTH)
      m = Regexp.new(
        '^' + [
          '([0-9]+:)',
          '(?<time>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          '(?<host>[0-9a-z\.\-]+)',
          '(?<port>[0-9]+)',
          '(?<invoice>[a-zA-Z0-9]{8,32}@[a-f0-9]{16})',
          '(?<suffixes>[a-zA-Z0-9 ]+)'
        ].join(' ') + '$'
      ).match(text)
      raise "Invalid score '#{text}'" if m.nil?
      Score.new(
        Time.parse(m[:time]), m[:host],
        m[:port].to_i, m[:invoice],
        m[:suffixes].split(' '),
        strength: strength
      )
    end

    def self.parse_text(text, strength: STRENGTH)
      parts = text.split(' ', 6)
      Score.new(
        Time.at(parts[0].hex),
        parts[1],
        parts[2].hex,
        "#{parts[3]}@#{parts[4]}",
        parts[5].split(' '),
        strength: strength
      )
    end

    def hash
      raise 'Score has zero value, there is no hash' if @suffixes.empty?
      @suffixes.reduce(body) do |prefix, suffix|
        Digest::SHA256.hexdigest(prefix + ' ' + suffix)[0, 63]
      end
    end

    def to_text
      prefix, bnf = @invoice.split('@')
      [
        @time.to_i.to_s(16),
        @host,
        @port.to_s(16),
        prefix,
        bnf,
        @suffixes.join(' ')
      ].join(' ')
    end

    def to_s
      [
        "#{value}:",
        @time.utc.iso8601,
        @host,
        @port,
        @invoice,
        @suffixes.join(' ')
      ].join(' ')
    end

    def to_h
      {
        value: value,
        host: @host,
        port: @port,
        invoice: @invoice,
        time: @time.utc.iso8601,
        suffixes: @suffixes,
        strength: @strength,
        hash: value.zero? ? nil : hash
      }
    end

    def reduced(max = 4)
      Score.new(
        @time, @host, @port, @invoice,
        @suffixes[0..max - 1], strength: @strength
      )
    end

    def next
      raise 'This score is not valid' unless valid?
      idx = 0
      loop do
        suffix = idx.to_s(16)
        score = Score.new(
          @time, @host, @port, @invoice, @suffixes + [suffix],
          strength: @strength
        )
        return score if score.valid?
        idx += 1
      end
    end

    def age_hours
      (Time.now - @time) / 60
    end

    def expired?
      @time < Time.now - 24 * 60
    end

    def body
      "#{@time.utc.iso8601} #{@host} #{@port} #{@invoice}"
    end

    def valid?
      @suffixes.empty? || hash.end_with?('0' * @strength)
    end

    def value
      @suffixes.length
    end
  end
end
