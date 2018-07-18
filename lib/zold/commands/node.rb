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
require_relative '../version'
require_relative '../score'
require_relative '../backtrace'
require_relative '../metronome'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../hungry_wallets'
require_relative '../remotes'
require_relative '../verbose_thread'
require_relative '../node/entrance'
require_relative '../node/safe_entrance'
require_relative '../node/spread_entrance'
require_relative '../node/async_entrance'
require_relative '../node/nodup_entrance'
require_relative '../node/front'
require_relative '../node/farm'
require_relative 'pull'
require_relative 'push'
require_relative 'pay'

# NODE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # NODE command
  class Node
    def initialize(wallets:, remotes:, copies:, log: Log::Quiet.new)
      @wallets = HungryWallets.new(wallets)
      @remotes = remotes
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = 'Usage: zold node [options]'
        o.string '--invoice',
          'The invoice you want to collect money to or the wallet ID',
          required: true
        o.integer '--port',
          "TCP port to open for the Net (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.integer '--bind-port',
          "TCP port to listen on (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.string '--host',
          'Host name (will attempt to auto-detect it, if not specified)'
        o.integer '--strength',
          "The strength of the score (default: #{Score::STRENGTH})",
          default: Score::STRENGTH
        o.integer '--threads',
          'How many threads to use for scores finding (default: 4)',
          default: 4
        o.bool '--dump-errors',
          'Make HTTP front-end errors visible in the log (false by default)',
          default: false
        o.bool '--standalone',
          'Never communicate with other nodes (mostly for testing)',
          default: false
        o.bool '--ignore-score-weakness',
          'Ignore score weakness of incoming requests and register those nodes anyway',
          default: false
        o.boolean '--nohup',
          'Run it in background, rebooting when a higher version is available in the network',
          default: false
        o.string '--nohup-command',
          'The command to run in server "nohup" mode (default: "gem install zold")',
          default: 'gem install zold'
        o.string '--nohup-log',
          'The file to log output into (default: zold.log)',
          default: 'zold.log'
        o.string '--save-pid',
          'The file to save process ID into right after start (only in NOHUP mode)'
        o.bool '--never-reboot',
          'Don\'t reboot when a new version shows up in the network',
          default: false
        o.bool '--routine-immediately',
          'Run all routines immediately, without waiting between executions (for testing mostly)',
          default: false
        o.string '--expose-version',
          "The version of the software to expose in JSON (default: #{VERSION})",
          default: VERSION
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          default: '~/.ssh/id_rsa'
        o.string '--network',
          "The name of the network (default: #{Wallet::MAIN_NETWORK})",
          require: true,
          default: Wallet::MAIN_NETWORK
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise '--invoice is mandatory' unless opts['invoice']
      if opts[:nohup]
        pid = nohup(opts)
        File.write(opts['save-pid'], pid) if opts['save-pid']
        @log.debug("Process ID #{pid} saved into \"#{opts['save-pid']}\"")
        @log.info(pid)
        return
      end
      Front.set(:log, @log)
      Front.set(:version, opts['expose-version'])
      Front.set(:protocol, Zold::PROTOCOL)
      Front.set(:logging, @log.debug?)
      Front.set(:home, Dir.pwd)
      @log.info("Home directory: #{Dir.pwd}")
      @log.info("Ruby version: #{RUBY_VERSION}")
      @log.info("Zold gem version: #{Zold::VERSION}")
      @log.info("Zold protocol version: #{Zold::PROTOCOL}")
      @log.info("Network ID: #{opts['network']}")
      host = opts[:host] || ip
      address = "#{host}:#{opts[:port]}".downcase
      @log.info("Node location: #{address}")
      @log.info("Local address: http://localhost:#{opts['bind-port']}/")
      Front.set(
        :server_settings,
        Logger: WebrickLog.new(@log),
        AccessLog: []
      )
      if opts['standalone']
        @remotes = Remotes::Empty.new
        @log.debug('Running in standalone mode! (will never talk to other remotes)')
      end
      Front.set(:ignore_score_weakness, opts['ignore-score-weakness'])
      Front.set(:network, opts['network'])
      Front.set(:wallets, @wallets)
      Front.set(:remotes, @remotes)
      Front.set(:copies, @copies)
      Front.set(:address, address)
      Front.set(:root, Dir.pwd)
      Front.set(:dump_errors, opts['dump-errors'])
      Front.set(:port, opts['bind-port'])
      Front.set(:reboot, !opts['never-reboot'])
      invoice = opts[:invoice]
      unless invoice.include?('@')
        if @wallets.find(Id.new(invoice)).exists?
          @log.info("Wallet #{invoice} already exists locally, won't pull")
        else
          @log.info("The wallet #{invoice} is not available locally, will pull now...")
          require_relative 'pull'
          Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
            ['pull', invoice, "--network=#{opts['network']}"]
          )
        end
        require_relative 'invoice'
        invoice = Invoice.new(wallets: @wallets, log: @log).run(['invoice', invoice])
      end
      SafeEntrance.new(
        NoDupEntrance.new(
          AsyncEntrance.new(
            SpreadEntrance.new(
              Entrance.new(@wallets, @remotes, @copies, address, log: @log, network: opts['network']),
              @wallets, @remotes, address,
              log: @log,
              ignore_score_weakeness: opts['ignore-score-weakness']
            ),
            File.join(Dir.pwd, '.zoldata/entrance'), log: @log
          ),
          @wallets
        ),
        network: opts['network']
      ).start do |entrance|
        Front.set(:entrance, entrance)
        Farm.new(invoice, File.join(Dir.pwd, 'farm'), log: @log)
          .start(host, opts[:port], threads: opts[:threads], strength: opts[:strength]) do |farm|
          Front.set(:farm, farm)
          metronome(farm, opts).start do |metronome|
            Front.set(:metronome, metronome)
            @log.info("Starting up the web front at http://#{host}:#{opts[:port]}...")
            Front.run!
            @log.info("The web front stopped at http://#{host}:#{opts[:port]}")
          end
        end
      end
      @log.info("The node #{host}:#{opts[:port]} is shut down, thanks for helping Zold network!")
    end

    private

    # Returns exit code
    def exec(cmd, nohup_log)
      start = Time.now
      Open3.popen2e(cmd) do |stdin, stdout, thr|
        nohup_log.print("Started process ##{thr.pid} from process ##{Process.pid}: #{cmd}\n")
        stdin.close
        until stdout.eof?
          begin
            line = stdout.gets
          rescue IOError => e
            line = Backtrace.new(e).to_s
          end
          nohup_log.print(line)
        end
        nohup_log.print("Nothing else left to read from ##{thr.pid}\n")
        code = thr.value.to_i
        nohup_log.print("Exit code of process ##{thr.pid} is #{code}, was alive for \
#{((Time.now - start) / 60).round} min: #{cmd}\n")
        code
      end
    end

    def nohup(opts)
      pid = fork do
        nohup_log = NohupLog.new(opts['nohup-log'])
        Signal.trap('HUP') do
          nohup_log.print("Received HUP, ignoring...\n")
        end
        Signal.trap('TERM') do
          nohup_log.print("Received TERM, terminating...\n")
          exit(-1)
        end
        myself = File.expand_path($PROGRAM_NAME)
        args = ARGV.delete_if { |a| a.start_with?('--nohup', '--home') }
        loop do
          begin
            code = exec("#{myself} #{args.join(' ')}", nohup_log)
            if code != 0
              nohup_log.print("Let's wait for a minute, because of the failure...")
              sleep(60)
            end
            exec(opts['nohup-command'], nohup_log)
          rescue StandardError => e
            nohup_log.print(Backtrace.new(e).to_s)
            nohup_log.print("Let's wait for a minutes, because of the exception...")
            sleep(60)
          end
        end
      end
      Process.detach(pid)
      pid
    end

    def metronome(farm, opts)
      metronome = Metronome.new(@log)
      require_relative 'routines/spread'
      metronome.add(Routines::Spread.new(opts, @wallets, @remotes, log: @log))
      unless opts['standalone']
        require_relative 'routines/reconnect'
        metronome.add(Routines::Reconnect.new(opts, @remotes, farm, network: opts['network'], log: Log::Quiet.new))
      end
      @log.info('Metronome created')
      metronome
    end

    def ip
      addr = Socket.ip_address_list.detect do |i|
        i.ipv4? && !i.ipv4_loopback? && !i.ipv4_multicast? && !i.ipv4_private?
      end
      raise 'Can\'t detect your IP address, you have to specify it in --host' if addr.nil?
      addr.ip_address
    end

    # Log facility for nohup
    class NohupLog
      def initialize(file)
        @file = file
      end

      def print(data)
        File.open(@file, 'a') { |f| f.print(data) }
      end
    end

    # Fake logging facility for Webrick
    class WebrickLog
      def initialize(log)
        @log = log
      end

      def info(msg)
        @log.debug(msg)
      end

      def debug(msg)
        # nothing
      end

      def error(msg)
        @log.error(msg)
      end

      def fatal(msg)
        @log.error(msg)
      end

      def debug?
        @log.info?
      end
    end
  end
end
