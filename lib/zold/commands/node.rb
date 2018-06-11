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
require_relative '../wallets'
require_relative '../remotes'
require_relative '../verbose_thread'
require_relative '../node/entrance'
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
      @wallets = wallets
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
        o.string '--host', "Host name (default: #{ip})",
          default: ip
        o.integer '--strength',
          "The strength of the score (default: #{Score::STRENGTH})",
          default: Score::STRENGTH
        o.integer '--threads',
          'How many threads to use for scores finding (default: 4)',
          default: 4
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
        o.string '--bonus-wallet',
          'The ID of the wallet to regularly send bonuses from (for nodes online)'
        o.string '--bonus-amount',
          'The amount of ZLD to pay to each remote as a bonus',
          default: '1'
        o.string '--private-key',
          'The location of RSA private key (default: ~/.ssh/id_rsa)',
          default: '~/.ssh/id_rsa'
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
      Front.set(:logging, @log.debug?)
      Front.set(:home, Dir.pwd)
      @log.info("Home directory: #{Dir.pwd}")
      @log.info("Ruby version: #{RUBY_VERSION}")
      @log.info("Zold gem version: #{Zold::VERSION}")
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
      Front.set(:wallets, @wallets)
      Front.set(:remotes, @remotes)
      Front.set(:copies, @copies)
      address = "#{opts[:host]}:#{opts[:port]}".downcase
      Front.set(:address, address)
      entrance = Entrance.new(@wallets, @remotes, @copies, address, log: @log)
      Front.set(:entrance, entrance)
      Front.set(:root, Dir.pwd)
      Front.set(:port, opts['bind-port'])
      Front.set(:reboot, !opts['never-reboot'])
      invoice = opts[:invoice]
      unless invoice.include?('@')
        require_relative 'pull'
        Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(['pull', invoice])
        require_relative 'invoice'
        invoice = Invoice.new(wallets: @wallets, log: @log).run(['invoice', invoice])
      end
      farm = Farm.new(invoice, File.join(Dir.pwd, 'farm'), log: @log)
      farm.start(
        opts[:host], opts[:port],
        threads: opts[:threads], strength: opts[:strength]
      )
      Front.set(:farm, farm)
      metronome = metronome(farm, opts)
      begin
        @log.info("Starting up the web front at http://#{opts[:host]}:#{opts[:port]}...")
        Front.run!
      ensure
        farm.stop
        metronome.stop
      end
    end

    private

    def exec(cmd, nohup_log)
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
        code = thr.value.to_i
        nohup_log.print("Exit code of process ##{thr.pid} is #{code}: #{cmd}\n")
        raise unless code.zero?
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
            exec("#{myself} #{args.join(' ')}", nohup_log)
            exec(opts['nohup-command'], nohup_log)
            # rubocop:disable Lint/RescueException
          rescue Exception => e
            # rubocop:enable Lint/RescueException
            nohup_log.print(Backtrace.new(e).to_s)
            raise e
          end
        end
      end
      Process.detach(pid)
      pid
    end

    def metronome(farm, opts)
      metronome = Metronome.new(@log)
      unless opts[:standalone]
        require_relative 'routines/reconnect'
        metronome.add(Routines::Reconnect.new(opts, @remotes, farm, log: @log))
      end
      if opts['bonus-wallet']
        require_relative 'routines/bonuses'
        metronome.add(Routines::Bonuses.new(opts, @wallets, @remotes, @copies, farm, log: @log))
      end
      @log.info('Metronome created')
      metronome
    end

    def ip
      addr = Socket.ip_address_list.detect do |i|
        i.ipv4? && !i.ipv4_loopback? && !i.ipv4_multicast? && !i.ipv4_private?
      end
      addr.nil? ? '127.0.0.1' : addr.ip_address
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

      def fatal(msg)
        @log.error(msg)
      end

      def debug?
        @log.info?
      end
    end
  end
end
