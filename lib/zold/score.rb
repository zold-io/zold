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

# The score.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Score
  class Score
    # time: UTC ISO 8601 string
    def initialize(time, host, port, suffixes = [], strength: 8)
      raise 'Time must be of type Time' unless time.is_a?(Time)
      raise 'Port must be of type Integer' unless port.is_a?(Integer)
      @time = time
      @host = host
      @port = port
      @suffixes = suffixes
      @strength = strength
    end

    def to_s
      "#{value}: #{@time.utc.iso8601} #{@host} #{@port} #{@suffixes.join(' ')}"
    end

    def to_h
      {
        value: value,
        host: @host,
        port: @port,
        time: @time.utc.iso8601,
        suffixes: @suffixes,
        strength: @strength
      }
    end

    def next
      idx = 0
      loop do
        suffix = idx.to_s(16)
        score = Score.new(
          @time, @host, @port, @suffixes + [suffix],
          strength: @strength
        )
        return score if score.valid?
        idx += 1
      end
    end

    def valid?
      start = "#{@time.utc.iso8601} #{@host} #{@port}"
      @suffixes.reduce(start) do |prefix, suffix|
        hex = Digest::SHA256.hexdigest(prefix + ' ' + suffix)
        return false unless hex.end_with?('0' * @strength)
        hex[0, 19]
      end
      true
    end

    def value
      @suffixes.length
    end
  end
end
