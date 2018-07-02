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
require 'semantic'
require 'rainbow'
require 'net/http'
require 'json'
require 'time'
require_relative 'args'
require_relative '../node/farm'
require_relative '../log'
require_relative '../json_page'
require_relative '../http'
require_relative '../remotes'
require_relative '../score'
require_relative '../wallet'

# REMOTE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Remote command
  class Remote
    def initialize(remotes:, farm: Farm::Empty.new, log: Log::Quiet.new)
      @remotes = remotes
      @farm = farm
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
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
    #{Rainbow('remote elect').green}
      Pick a random remote node as a target for a bonus awarding
    #{Rainbow('remote trim').green}
      Remove the least reliable nodes
    #{Rainbow('remote select [options]').green}
      Select the strongest n nodes.
    #{Rainbow('remote update').green}
      Check each registered remote node for availability
Available options:"
        o.integer '--tolerate',
          'Maximum level of errors we are able to tolerate',
          default: Remotes::TOLERANCE
        o.bool '--ignore-score-weakness',
          'Don\'t complain when their score is too weak',
          default: false
        o.bool '--ignore-score-value',
          'Don\'t complain when their score is too small',
          default: false
        o.bool '--force',
          'Add/remove if if this operation is not possible',
          default: false
        o.bool '--skip-ping',
          'Don\'t ping back the node when adding it (not recommended)',
          default: false
        o.string '--network',
          "The name of the network we work in (default: #{Wallet::MAIN_NETWORK}",
          required: true,
          default: Wallet::MAIN_NETWORK
        o.bool '--reboot',
          'Exit if any node reports version higher than we have',
          default: false

        # @todo #292:30min Group options by subcommands
        #  Having all the options in one place _rather than grouping them by subcommands_
        #  makes the help totally misleading and hard to read.
        #  Not all the options are valid for every command - that's the key here.
        #  The option below (`--max-nodes`) is an example.
        #  **Next actions:**
        #  - Implement the suggestion above.
        #  - Remove note from the --max-nodes option saying that it applies to the select
        #  subcommand only.
        o.integer '--max-nodes',
          "This applies only to the select subcommand. Number of nodes to limit to. Defaults to #{Remotes::MAX_NODES}.",
          default: Remotes::MAX_NODES
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      command = mine[0]
      raise "A command is required, try 'zold remote --help'" unless command
      case command
      when 'show'
        show
      when 'clean'
        clean
      when 'reset'
        reset
      when 'add'
        add(mine[1], mine[2] ? mine[2].to_i : Remotes::PORT, opts)
      when 'remove'
        remove(mine[1], mine[2] ? mine[2].to_i : Remotes::PORT, opts)
      when 'elect'
        elect(opts)
      when 'trim'
        trim(opts)
      when 'update'
        update(opts)
        update(opts, false)
      when 'select'
        select(opts)
      else
        raise "Unknown command '#{command}'"
      end
    end

    private

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
      @log.debug("Remote nodes set back to default, #{@remotes.all.count} total")
    end

    def add(host, port, opts)
      unless opts['skip-ping']
        res = Http.new("http://#{host}:#{port}/version", network: opts['network']).get
        raise "The node #{host}:#{port} is not responding (code is #{res.code})" unless res.code == '200'
      end
      if @remotes.exists?(host, port)
        raise "#{host}:#{port} already exists in the list" unless opts['force']
        @log.debug("#{host}:#{port} already exists in the list")
      else
        @remotes.add(host, port)
        @log.info("#{host}:#{port} added to the list, #{@remotes.all.count} total")
      end
      @log.debug("There are #{@remotes.all.count} remote nodes in the list")
    end

    def remove(host, port, opts)
      if @remotes.exists?(host, port)
        @remotes.remove(host, port)
        @log.info("#{host}:#{port} removed from the list")
      else
        raise "#{host}:#{port} is not in the list" unless opts['force']
        @log.debug("#{host}:#{port} is not in the list")
      end
      @log.debug("There are #{@remotes.all.count} remote nodes in the list")
    end

    # Returns an array of Zold::Score
    def elect(opts)
      scores = []
      @remotes.iterate(@log, farm: @farm) do |r|
        res = r.http('/').get
        r.assert_code(200, res)
        json = JsonPage.new(res.body).to_hash
        score = Score.parse_json(json['score'])
        r.assert_valid_score(score)
        r.assert_score_ownership(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        r.assert_score_value(score, Tax::EXACT_SCORE) unless opts['ignore-score-value']
        scores << score
      end
      scores = scores.sample(1)
      if scores.empty?
        @log.info("No winners elected out of #{@remotes.all.count} remotes")
      else
        @log.info("Elected: #{scores[0]}")
      end
      scores
    end

    def trim(opts)
      @remotes.all.each do |r|
        remove(r[:host], r[:port], opts) if r[:errors] > opts['tolerate']
      end
      @log.info("The list of remotes trimmed, #{@remotes.all.count} nodes left there")
    end

    def update(opts, deep = true)
      capacity = []
      @remotes.iterate(@log, farm: @farm) do |r|
        start = Time.now
        res = r.http('/remotes').get
        r.assert_code(200, res)
        json = JsonPage.new(res.body).to_hash
        score = Score.parse_json(json['score'])
        r.assert_valid_score(score)
        r.assert_score_ownership(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        @remotes.rescore(score.host, score.port, score.value)
        if Semantic::Version.new(VERSION) < Semantic::Version.new(json['version'])
          if opts['reboot']
            @log.info("#{r}: their version #{json['version']} is higher than mine #{VERSION}, reboot! \
(use --never-reboot to avoid this from happening)")
            terminate
          end
          @log.debug("#{r}: their version #{json['version']} is higher than mine #{VERSION}, \
it's recommended to reboot, but I don't do it because of --never-reboot")
        end
        if deep
          json['all'].each do |s|
            add(s['host'], s['port'], opts) unless @remotes.exists?(s['host'], s['port'])
          end
        end
        capacity << { host: score.host, port: score.port, count: json['all'].count }
        @log.info("#{r}: the score is #{Rainbow(score.value).green} (#{json['version']}) \
in #{(Time.now - start).round(2)}s")
      end
      max_capacity = capacity.map { |c| c[:count] }.max || 0
      capacity.each do |c|
        @remotes.error(c[:host], c[:port]) if c[:count] < max_capacity
      end
      total = @remotes.all.size
      if total.zero?
        @log.debug("The list of remotes is #{Rainbow('empty').red}, run 'zold remote reset'!")
      else
        @log.debug("There are #{total} known remotes")
      end
    end

    # @todo #292:30min Implement the logic of selecting the nodes as per #292.
    #  The strongest n nodes should be selected, where n = opts['max-nodes'].
    def select(_opts)
      raise NotImplementedError, 'This feature is not yet implemented.'
    end

    def terminate
      @log.info("All threads before exit: #{Thread.list.map { |t| "#{t.name}/#{t.status}" }.join(', ')}")
      require_relative '../node/front'
      Front.stop!
    end
  end
end
