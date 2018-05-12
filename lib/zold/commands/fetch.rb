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

require 'uri'
require 'json'
require 'time'
require_relative '../log.rb'
require_relative '../http.rb'
require_relative '../score.rb'

# FETCH command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # FETCH pulling command
  class Fetch
    def initialize(wallet:, remotes:, copies:, log: Log::Quiet.new)
      @wallet = wallet
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(_ = [])
      total = 0
      @remotes.all.each do |r|
        uri = URI("#{r[:home]}wallet/#{@wallet.id}")
        res = Http.new(uri).get
        unless res.code == '200'
          @log.error("#{r[:host]}:#{r[:port]} \
#{Rainbow(res.code).red}/#{res.message} at #{uri}")
          next
        end
        json = JSON.parse(res.body)
        score = Score.new(
          Time.parse(json['score']['time']),
          r[:host],
          r[:port],
          json['score']['suffixes']
        )
        unless score.valid?
          @log.error("#{r[:host]}:#{r[:port]} invalid score")
          next
        end
        total += 1
        @copies.add(json['body'], r[:host], r[:port], score.value)
        @log.info(
          "#{r[:host]}:#{r[:port]} #{json['body'].length}b/\
#{Rainbow(score.value).green} (v.#{json['version']})"
        )
      end
      @log.debug("#{total} copies fetched, \
there are #{@copies.all.count} available locally")
    end
  end
end
