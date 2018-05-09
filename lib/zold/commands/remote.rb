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
require_relative '../log.rb'
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
          @log.info(r[:address] + Rainbow(":#{r[:port]}").gray + score)
        end
      when 'add'
        host = args[1]
        @remotes.add(host)
        @log.info("Remote added: #{host}")
      when 'remove'
        host = args[1]
        @remotes.remove(host)
        @log.info("Remote removed: #{host}")
      when 'update'
        update
        total = @remotes.all.size
        if total.zero?
          @log.info("The list of remotes is #{Rainbow('empty').red}!")
          @log.info("Run 'zold remote add b1.zold.io` and then `zold update`")
        else
          @log.info("There are #{total} known remotes")
        end
      else
        raise "Command '#{command}' is not supported"
      end
    end

    def update
      @remotes.all.each do |r|
        begin
          uri = URI("http://#{r[:address]}:#{r[:port]}/score.json")
          http = Net::HTTP.new(uri.host, uri.port)
          http.read_timeout = 500
          http.request_get(uri.path) do |response|
            json = JSON.parse(response.body)
            score = Score.new(
              json['date'], r[:address],
              r[:port], json['suffixes']
            )
            if score.valid?
              @remotes.rescore(r[:address], r[:port], score.value)
              @log.info("#{r[:address]}: #{Rainbow(score.value).green}")
            else
              @remotes.remove(r[:address], r[:port])
              @log.info("#{r[:address]}: score is #{Rainbow('invalid').red}")
            end
          end
        rescue StandardError => e
          @remotes.remove(r[:address], r[:port])
          @log.info(
            "#{r[:address]} #{Rainbow('removed').red}: \
#{e.class.name} #{e.message[0..200].gsub(/[^a-zA-Z0-9 -+<>]/, '.')}"
          )
        end
      end
    end
  end
end
