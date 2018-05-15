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

require 'slop'
require 'rainbow'
require 'net/http'
require 'json'
require 'time'
require_relative '../log'
require_relative '../http'
require_relative '../remotes'
require_relative '../score'

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
      opts = Slop.parse(args, help: true) do |o|
        o.banner = "Usage: zold remote <command> [options]
Available commands:
    #{Rainbow('remote show').green}
      Show all registered remote nodes
    #{Rainbow('remote clean').green}
      Remove all registered remote nodes
    #{Rainbow('remote reset').green}
      Restore it back to the default list of nodes
    #{Rainbow('remote add').green} host [port]
      Add a new remote node
    #{Rainbow('remote remove').green} host [port]
      Remove the remote node
    #{Rainbow('remote update').green}
      Check each registered remote node for availability
Available options:"
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak',
          default: false
        o.bool '--help', 'Print instructions'
      end
      command = opts.arguments[0]
      case command
      when 'show'
        show
      when 'clean'
        clean
      when 'reset'
        reset
      when 'add'
        add(opts.arguments[1], opts.arguments[2] ? opts.arguments[2].to_i : Remotes::PORT)
      when 'remove'
        remove(opts.arguments[1], opts.arguments[2] ? opts.arguments[2].to_i : Remotes::PORT)
      when 'update'
        update(opts)
        update(opts, false)
      else
        @log.info(opts.to_s)
      end
    end

    def show
      @remotes.all.each do |r|
        score = Rainbow("/#{r[:score]}").color(r[:score] > 0 ? :green : :red)
        @log.info(r[:host] + Rainbow(":#{r[:port]}").gray + score)
      end
    end

    def clean
      @remotes.clean
      @log.debug('All remote nodes deleted')
    end

    def reset
      @remotes.reset
      @log.debug('Remote nodes set back to default')
    end

    def add(host, port)
      @remotes.add(host, port)
      @log.info("#{host}:#{port} added to the list")
      @log.info("There are #{@remotes.all.count} remote nodes in the list")
    end

    def remove(host, port)
      @remotes.remove(host, port)
      @log.info("#{host}:#{port} removed from the list")
      @log.info("There are #{@remotes.all.count} remote nodes in the list")
    end

    def update(opts, deep = true)
      @remotes.all.each do |r|
        uri = URI("#{r[:home]}remotes")
        res = Http.new(uri).get
        unless res.code == '200'
          @remotes.remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} #{res.code} \"#{res.message}\" #{uri}")
          next
        end
        begin
          json = JSON.parse(res.body)
        rescue JSON::ParserError => e
          remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} \"#{e.message}\": #{res.body}")
          next
        end
        score = Score.parse_json(json['score'])
        unless score.valid?
          remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} invalid score")
          next
        end
        if score.expired?
          remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} expired score")
          next
        end
        if score.strength < Score::STRENGTH && !opts['ignore-score-weakness']
          remove(r[:host], r[:port])
          @log.info("#{Rainbow(r[:host]).red} score too weak: #{score.strength}")
          next
        end
        if r[:host] != score.host || r[:port] != score.port
          @remotes.remove(r[:host], r[:port])
          @remotes.add(score.host, score.port)
          @log.info("#{r[:host]}:#{r[:port]} renamed to #{score.host}:#{score.port}")
        end
        @remotes.rescore(score.host, score.port, score.value)
        if deep
          json['all'].each do |s|
            add(s['host'], s['port']) unless @remotes.exists?(s['host'], s['port'])
          end
        end
        @log.info("#{r[:host]}:#{r[:port]}: #{Rainbow(score.value).green} (v.#{json['version']})")
      end
      total = @remotes.all.size
      if total.zero?
        @log.debug("The list of remotes is #{Rainbow('empty').red}!")
        @log.debug("Run 'zold remote add b1.zold.io` and then `zold update`")
      else
        @log.debug("There are #{total} known remotes")
      end
    end
  end
end
