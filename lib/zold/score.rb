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

require 'openssl'
require 'time'

# The score.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Score
  class Score
    # Default strength for the entire system, in production mode.
    STRENGTH = 6

    attr_reader :time, :host, :port, :invoice, :suffixes, :strength, :created

    def initialize(time: Time.now, host:, port:, invoice:, suffixes: [],
      strength: Score::STRENGTH, created: Time.now)
      @time = time
      @host = host
      @port = port
      @invoice = invoice
      @suffixes = suffixes
      @strength = strength
      @created = created
    end

    # The default no-value score.
    ZERO = Score.new(time: Time.now, host: 'localhost', port: 80, invoice: 'NOPREFIX@ffffffffffffffff')

    def self.parse_json(json)
      raise "Time in JSON is broken: #{json}" unless json['time'] =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
      raise "Host is wrong: #{json}" unless json['host'] =~ /^[0-9a-z\.\-]+$/
      raise "Port is wrong: #{json}" unless json['port'].is_a?(Integer)
      raise "Invoice is wrong: #{json}" unless json['invoice'] =~ /^[a-zA-Z0-9]{8,32}@[a-f0-9]{16}$/
      raise "Suffixes not array: #{json}" unless json['suffixes'].is_a?(Array)
      Score.new(
        time: Time.parse(json['time']), host: json['host'],
        port: json['port'], invoice: json['invoice'], suffixes: json['suffixes'],
        strength: json['strength']
      )
    end

    def self.parse(text)
      re = Regexp.new(
        '^' + [
          '([0-9]+)/(?<strength>[0-9]+):',
          ' (?<time>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)',
          ' (?<host>[0-9a-z\.\-]+)',
          ' (?<port>[0-9]+)',
          ' (?<invoice>[a-zA-Z0-9]{8,32}@[a-f0-9]{16})',
          '(?<suffixes>( [a-zA-Z0-9]+)*)'
        ].join + '$'
      )
      m = re.match(text.strip)
      raise "Invalid score '#{text}', doesn't match: #{re}" if m.nil?
      Score.new(
        time: Time.parse(m[:time]), host: m[:host],
        port: m[:port].to_i, invoice: m[:invoice],
        suffixes: m[:suffixes].split(' '),
        strength: m[:strength].to_i
      )
    end

    def self.parse_text(text)
      parts = text.split(' ', 7)
      Score.new(
        time: Time.at(parts[1].hex),
        host: parts[2],
        port: parts[3].hex,
        invoice: "#{parts[4]}@#{parts[5]}",
        suffixes: parts[6] ? parts[6].split(' ') : [],
        strength: parts[0].to_i
      )
    end

    def hash
      raise 'Score has zero value, there is no hash' if @suffixes.empty?
      @suffixes.reduce(prefix) do |pfx, suffix|
        OpenSSL::Digest::SHA256.new("#{pfx} #{suffix}").hexdigest
      end
    end

    def to_mnemo
      "#{value}:#{@time.strftime('%H%M')}"
    end

    def to_text
      pfx, bnf = @invoice.split('@')
      [
        @strength,
        @time.to_i.to_s(16),
        @host,
        @port.to_s(16),
        pfx,
        bnf,
        @suffixes.join(' ')
      ].join(' ')
    end

    def to_s
      [
        "#{value}/#{@strength}:",
        @time.utc.iso8601,
        @host,
        @port,
        @invoice,
        @suffixes.join(' ')
      ].join(' ').strip
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
        hash: value.zero? ? nil : hash,
        expired: expired?,
        valid: valid?,
        age: (age / 60).round,
        created: @created.utc.iso8601
      }
    end

    def reduced(max = 4)
      Score.new(
        time: @time, host: @host, port: @port, invoice: @invoice,
        suffixes: @suffixes[0..[max, suffixes.count].min - 1],
        strength: @strength
      )
    end

    def next
      raise 'This score is not valid' unless valid?
      idx = 0
      loop do
        suffix = idx.to_s(16)
        score = Score.new(
          time: @time, host: @host, port: @port,
          invoice: @invoice, suffixes: @suffixes + [suffix],
          strength: @strength
        )
        return score if score.valid?
        if score.expired?
          return Score.new(
            time: Time.now, host: @host, port: @port, invoice: @invoice,
            suffixes: [], strength: @strength
          )
        end
        idx += 1
      end
    end

    def age
      Time.now - @time
    end

    def expired?(hours = 24)
      age > hours * 60 * 60
    end

    def prefix
      "#{@time.utc.iso8601} #{@host} #{@port} #{@invoice}"
    end

    def valid?
      @suffixes.empty? || hash.end_with?('0' * @strength)
    end

    def value
      @suffixes.length
    end

    def zero?
      @suffixes.empty?
    end
  end
end
