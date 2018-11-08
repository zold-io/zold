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

require 'slop'
require 'semantic'
require 'rainbow'
require 'net/http'
require 'json'
require 'time'
require 'zold/score'
require_relative 'args'
require_relative '../node/farm'
require_relative '../log'
require_relative '../age'
require_relative '../json_page'
require_relative '../http'
require_relative '../remotes'
require_relative '../wallet'
require_relative '../gem'

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
    #{Rainbow('remote defaults').green}
      Add all default nodes to the list
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
        o.array '--ignore-node',
          'Ignore this node and never add it to the list',
          default: []
        o.integer '--min-score',
          "The minimum score required for winning the election (default: #{Tax::EXACT_SCORE})",
          default: Tax::EXACT_SCORE
        o.integer '--max-winners',
          'The maximum amount of election winners the election (default: 1)',
          default: 1
        o.bool '--skip-ping',
          'Don\'t ping back the node when adding it (not recommended)',
          default: false
        o.integer '--depth',
          'The amount of update cycles to run, in order to fetch as many nodes as possible (default: 2)',
          default: 2
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
      when 'defaults'
        defaults
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
      when 'select'
        select(opts)
      else
        raise "Unknown command '#{command}'"
      end
    end

    private

    def show
      @remotes.all.each do |r|
        score = Rainbow("/#{r[:score]}").color(r[:score].positive? ? :green : :red)
        @log.info(r[:host] + Rainbow(":#{r[:port]}").gray + score)
      end
    end

    def clean
      before = @remotes.all.count
      @remotes.clean
      @log.debug("All #{before} remote nodes deleted")
    end

    def reset
      clean
      defaults
    end

    def defaults
      @remotes.defaults
      @log.debug("Default remote nodes were added to the list, #{@remotes.all.count} total")
    end

    def add(host, port, opts)
      if opts['ignore-node'].include?("#{host}:#{port}")
        @log.info("#{host}:#{port} won't be added since it's in the --ignore-node list")
        return
      end
      unless opts['skip-ping']
        res = Http.new(uri: "http://#{host}:#{port}/version", network: opts['network']).get
        raise "The node #{host}:#{port} is not responding, #{res.code}:#{res.message}" unless res.code == '200'
      end
      @remotes.add(host, port)
      @log.info("#{host}:#{port} added to the list, #{@remotes.all.count} total")
    end

    def remove(host, port, _)
      @remotes.remove(host, port)
      @log.info("#{host}:#{port} removed from the list, #{@remotes.all.count} total")
    end

    # Returns an array of Zold::Score
    def elect(opts)
      scores = []
      @remotes.iterate(@log, farm: @farm) do |r|
        uri = '/'
        res = r.http(uri).get
        r.assert_code(200, res)
        json = JsonPage.new(res.body, uri).to_hash
        score = Score.parse_json(json['score'])
        r.assert_valid_score(score)
        r.assert_score_ownership(score)
        r.assert_score_strength(score) unless opts['ignore-score-weakness']
        r.assert_score_value(score, opts['min-score']) unless opts['ignore-score-value']
        scores << score
      end
      scores = scores.sample(opts['max-winners'])
      if scores.empty?
        @log.info("No winners elected out of #{@remotes.all.count} remotes")
      else
        scores.each { |s| @log.info("Elected: #{s}") }
      end
      scores
    end

    def trim(opts)
      all = @remotes.all
      all.each do |r|
        next if r[:errors] <= opts['tolerate']
        @remotes.remove(r[:host], r[:port])
        @log.info("#{r[:host]}:#{r[:port]} removed because of #{r[:errors]} errors (over #{opts['tolerate']})")
      end
      @log.info("The list of #{all.count} remotes trimmed, #{@remotes.all.count} nodes left there")
    end

    def update(opts)
      st = Time.now
      capacity = []
      opts['depth'].times do |cycle|
        @remotes.iterate(@log, farm: @farm) do |r|
          start = Time.now
          uri = '/remotes'
          res = r.http(uri).get
          r.assert_code(200, res)
          json = JsonPage.new(res.body, uri).to_hash
          score = Score.parse_json(json['score'])
          r.assert_valid_score(score)
          r.assert_score_ownership(score)
          r.assert_score_strength(score) unless opts['ignore-score-weakness']
          @remotes.rescore(score.host, score.port, score.value)
          gem = Zold::Gem.new
          if Semantic::Version.new(VERSION) < Semantic::Version.new(json['version']) ||
             Semantic::Version.new(VERSION) < Semantic::Version.new(gem.last_version)
            if opts['reboot']
              @log.info("#{r}: their version #{json['version']} is higher than mine #{VERSION}, reboot! \
  (use --never-reboot to avoid this from happening)")
              terminate
            end
            @log.debug("#{r}: their version #{json['version']} is higher than mine #{VERSION}, \
  it's recommended to reboot, but I don't do it because of --never-reboot")
          end
          if cycle.positive?
            json['all'].each do |s|
              if opts['ignore-node'].include?("#{s['host']}:#{s['port']}")
                @log.debug("#{s['host']}:#{s['port']}, which is found at #{r} \
  won't be added since it's in the --ignore-node list")
                next
              end
              next if @remotes.exists?(s['host'], s['port'])
              @remotes.add(s['host'], s['port'])
              @log.info("#{s['host']}:#{s['port']} found at #{r} and added to the list of #{@remotes.all.count}")
            end
          end
          capacity << { host: score.host, port: score.port, count: json['all'].count }
          @log.info("#{r}: the score is #{Rainbow(score.value).green} (#{json['version']}) in #{Age.new(start)}")
        end
      end
      max_capacity = capacity.map { |c| c[:count] }.max || 0
      capacity.each do |c|
        @remotes.error(c[:host], c[:port]) if c[:count] < max_capacity
      end
      total = @remotes.all.size
      if total.zero?
        @log.info("The list of remotes is #{Rainbow('empty').red}, run 'zold remote reset'!")
      else
        @log.info("There are #{total} known remotes after update in #{Age.new(st)}")
      end
    end

    def select(opts)
      selected = @remotes.all.sort_by { |r| r[:score] }.reverse.first(opts['max-nodes'])
      (@remotes.all - selected).each do |r|
        @remotes.remove(r[:host], r[:port])
      end
    end

    def terminate
      @log.info("All threads before exit: #{Thread.list.map { |t| "#{t.name}/#{t.status}" }.join(', ')}")
      require_relative '../node/front'
      Front.stop!
    end
  end
end
