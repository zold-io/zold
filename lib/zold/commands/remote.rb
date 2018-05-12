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

require 'rainbow'
require 'net/http'
require 'json'
require 'time'
require_relative '../log.rb'
require_relative '../http.rb'
require_relative '../remotes.rb'
require_relative '../score.rb'

# REMOTE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Remote command
  class Remote
    def initialize(remotes:, log: Log::Quiet.new)
      @remotes = remotes
      @log = log
    end

    def run(args = [])
      command = args[0]
      case command
      when 'show'
        @remotes.all.each do |r|
          score = Rainbow("/#{r[:score]}").color(r[:score] > 0 ? :green : :red)
          @log.info(r[:host] + Rainbow(":#{r[:port]}").gray + score)
        end
      when 'clean'
        @remotes.clean
        @log.debug('All remote nodes deleted')
      when 'reset'
        @remotes.reset
        @log.debug('Remote nodes set back to default')
      when 'add'
        host = args[1]
        port = args[2]
        @remotes.add(host, port)
        @log.info("#{host}:#{port}: added")
      when 'remove'
        host = args[1]
        port = args[2]
        @remotes.remove(host, port)
        @log.info("#{host}:#{port}: removed")
      when 'update'
        update
        total = @remotes.all.size
        if total.zero?
          @log.debug("The list of remotes is #{Rainbow('empty').red}!")
          @log.debug(
            "Run 'zold remote add b1.zold.io 80` and then `zold update`"
          )
        else
          @log.debug("There are #{total} known remotes")
        end
      else
        raise "Command '#{command}' is not supported"
      end
    end

    def update
      @remotes.all.each do |r|
        uri = URI("#{r[:home]}remotes")
        res = Http.new(uri).get
        unless res.code == '200'
          @remotes.remove(r[:host], r[:port])
          @log.info(
            "#{Rainbow(r[:host]).red} #{res.code} \"#{res.message}\" #{uri}"
          )
          next
        end
        begin
          json = JSON.parse(res.body)
        rescue JSON::ParserError => e
          @remotes.remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} \"#{e.message}\": #{res.body}")
          next
        end
        score = Score.new(
          Time.parse(json['score']['time']), r[:host],
          r[:port], json['score']['suffixes']
        )
        unless score.valid?
          @remotes.remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} invalid score")
          next
        end
        @remotes.rescore(r[:host], r[:port], score.value)
        json['all'].each { |s| run(['add', s['host'], s['port']]) }
        @log.info("#{r[:host]}:#{r[:port]}: #{Rainbow(score.value).green}")
      end
    end
  end
end
