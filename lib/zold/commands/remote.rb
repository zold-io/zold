# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
require_relative 'thread_badge'
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
    prepend ThreadBadge

    def initialize(remotes:, farm: Farm::Empty.new, log: Log::NULL)
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
    #{Rainbow('remote masters').green}
      Add all \"master\" nodes to the list
    #{Rainbow('remote add').green} host [port]
      Add a new remote node
    #{Rainbow('remote remove').green} host [port]
      Remove the remote node
    #{Rainbow('remote elect').green}
      Pick a random remote node as a target for a bonus awarding
    #{Rainbow('remote trim').green}
      Remove the least reliable nodes
    #{Rainbow('remote select [options]').green}
      Select the most reliable N nodes
    #{Rainbow('remote update').green}
      Check each registered remote node for availability
Available options:"
        o.integer '--tolerate',
          "Maximum level of errors we are able to tolerate (default: #{Remotes::TOLERANCE})",
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
        o.bool '--ignore-if-exists',
          'Ignore the node while adding if it already exists in the list',
          default: false
        o.bool '--ignore-masters',
          'Don\'t elect master nodes, only edges',
          default: false
        o.bool '--masters-too',
          'Give no priviledges to masters, treat them as other nodes',
          default: false
        o.integer '--min-score',
          "The minimum score required for winning the election (default: #{Tax::EXACT_SCORE})",
          default: Tax::EXACT_SCORE
        o.integer '--max-winners',
          'The maximum amount of election winners the election (default: 1)',
          default: 1
        o.integer '--retry',
          'How many times to retry each node before reporting a failure (default: 2)',
          default: 2
        o.bool '--skip-ping',
          'Don\'t ping back the node when adding it (not recommended)',
          default: false
        o.bool '--ignore-ping',
          'Don\'t fail if ping fails, just report the problem in the log',
          default: false
        o.integer '--depth',
          'The amount of update cycles to run, in order to fetch as many nodes as possible (default: 3)',
          default: 3
        o.string '--network',
          "The name of the network we work in (default: #{Wallet::MAINET})",
          required: true,
          default: Wallet::MAINET
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
          "Number of nodes to limit to (default: #{Remotes::MAX_NODES})",
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
        reset(opts)
      when 'masters'
        masters(opts)
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
        @log.info(
          [
            "#{r[:host]}:#{r[:port]}#{score}",
            r[:errors].positive? ? " #{r[:errors]} errors" : '',
            r[:master] ? ' [master]' : ''
          ].join
        )
      end
    end

    def clean
      before = @remotes.all.count
      @remotes.clean
      @log.debug("All #{before} remote nodes deleted")
    end

    def reset(opts)
      clean
      masters(opts)
    end

    def masters(opts)
      @remotes.masters do |host, port|
        !opts['ignore-node'].include?("#{host}:#{port}")
      end
      @log.debug("Masters nodes were added to the list, #{@remotes.all.count} total")
    end

    def add(host, port, opts)
      if opts['ignore-node'].include?("#{host}:#{port}")
        @log.debug("#{host}:#{port} won't be added since it's in the --ignore-node list")
        return
      end
      if opts['ignore-if-exists'] && @remotes.exists?(host, port)
        @log.debug("#{host}:#{port} already exists, won't add because of --ignore-if-exists")
        return
      end
      return unless ping(host, port, opts)
      if @remotes.exists?(host, port)
        @log.debug("#{host}:#{port} already exists among #{@remotes.all.count} others")
      else
        @remotes.add(host, port)
        @log.debug("#{host}:#{port} added to the list, #{@remotes.all.count} total")
      end
    end

    def remove(host, port, _)
      @remotes.remove(host, port)
      @log.debug("#{host}:#{port} removed from the list, #{@remotes.all.count} total")
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
        if r.master? && opts['--ignore-masters']
          @log.debug("#{r} ignored, it's a master node")
          next
        end
        scores << score
      end
      scores = scores.sample(opts['max-winners'])
      if scores.empty?
        @log.info("No winners elected out of #{@remotes.all.count} remotes")
      else
        scores.each { |s| @log.info("Elected: #{s.reduced(4)}") }
      end
      scores.sort_by(&:value).reverse
    end

    def trim(opts)
      all = @remotes.all
      all.each do |r|
        next if r[:errors] <= opts['tolerate']
        @remotes.remove(r[:host], r[:port]) if !opts['masters-too'] || !r[:master]
        @log.debug("#{r[:host]}:#{r[:port]} removed because of #{r[:errors]} errors (over #{opts['tolerate']})")
      end
      @log.info("The list of #{all.count} remotes trimmed down to #{@remotes.all.count} nodes")
    end

    def update(opts)
      st = Time.now
      seen = Set.new
      capacity = []
      opts['depth'].times do
        @remotes.iterate(@log, farm: @farm) do |r|
          if seen.include?(r.to_mnemo)
            @log.debug("#{r} seen already, won't check again")
            next
          end
          seen << r.to_mnemo
          start = Time.now
          update_one(r, opts) do |json, score|
            r.assert_valid_score(score)
            r.assert_score_ownership(score)
            r.assert_score_strength(score) unless opts['ignore-score-weakness']
            @remotes.rescore(score.host, score.port, score.value)
            reboot(r, json, opts)
            json['all'].each do |s|
              next if @remotes.exists?(s['host'], s['port'])
              add(s['host'], s['port'], opts)
            end
            capacity << { host: score.host, port: score.port, count: json['all'].count }
            @log.debug("#{r}: the score is #{Rainbow(score.value).green} (#{json['version']}) in #{Age.new(start)}")
          end
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
        @log.info("There are #{total} known remotes with the overall score of \
#{@remotes.all.map { |r| r[:score] }.inject(&:+)}, after update in #{Age.new(st)}")
      end
    end

    def update_one(r, opts)
      attempt = 0
      begin
        uri = '/remotes'
        res = r.http(uri).get
        r.assert_code(200, res)
        json = JsonPage.new(res.body, uri).to_hash
        score = Score.parse_json(json['score'])
        yield json, score
      rescue JsonPage::CantParse, Score::CantParse, RemoteNode::CantAssert => e
        attempt += 1
        if attempt < opts['retry']
          @log.error("#{r} failed to read, trying again (attempt no.#{attempt}): #{e.message}")
          retry
        end
        raise e
      end
    end

    def reboot(r, json, opts)
      return unless json['repo'] == Zold::REPO
      mine = Semantic::Version.new(VERSION)
      if mine < Semantic::Version.new(json['version'])
        if opts['reboot']
          @log.info("#{r}: their version #{json['version']} is higher than mine #{VERSION}, reboot! \
(use --never-reboot to avoid this from happening)")
          terminate
        end
        @log.debug("#{r}: their version #{json['version']} is higher than mine #{VERSION}, \
it's recommended to reboot, but I don't do it because of --never-reboot")
      end
      if mine < Semantic::Version.new(Zold::Gem.new.last_version)
        if opts['reboot']
          @log.info("#{r}: the version of the gem is higher than mine #{VERSION}, reboot! \
(use --never-reboot to avoid this from happening)")
          terminate
        end
        @log.debug("#{r}: gem version is higher than mine #{VERSION}, \
it's recommended to reboot, but I don't do it because of --never-reboot")
      end
      @log.debug("#{r}: gem version is lower or equal to mine #{VERSION}, no need to reboot")
    end

    def select(opts)
      @remotes.all.shuffle.sort_by { |r| r[:errors] }.reverse.each_with_index do |r, idx|
        next if idx < opts['max-nodes']
        next if r[:master] && !opts['masters-too']
        @remotes.remove(r[:host], r[:port])
        @log.debug("Remote #{r[:host]}:#{r[:port]}/#{r[:score]}/#{r[:errors]}e removed from the list")
      end
      @log.info("#{@remotes.all.count} remote nodes were selected to stay in the list")
    end

    def terminate
      @log.info("All threads before exit: #{Thread.list.map { |t| "#{t.name}/#{t.status}" }.join(', ')}")
      require_relative '../node/front'
      Front.stop!
    end

    def ping(host, port, opts)
      return true if opts['skip-ping']
      res = Http.new(uri: "http://#{host}:#{port}/version", network: opts['network']).get
      return true if res.status == 200
      raise "The node #{host}:#{port} is not responding, #{res.status}:#{res.status_line}" unless opts['ignore-ping']
      @log.error("The node #{host}:#{port} is not responding, #{res.status}:#{res.status_line}")
      false
    end
  end
end
