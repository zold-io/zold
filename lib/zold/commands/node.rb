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
require_relative '../score'
require_relative '../wallets'
require_relative '../remotes'
require_relative '../node/entrance'
require_relative '../node/front'
require_relative '../node/farm'

# NODE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # NODE command
  class Node
    def initialize(log: Log::Quiet.new)
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = 'Usage: zold node [options]'
        o.string '--invoice',
          'The invoice you want to collect money to or the wallet ID'
        o.integer '--port',
          "TCP port to open for the Net (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.integer '--bind-port',
          "TCP port to listen on (default: #{Remotes::PORT})",
          default: Remotes::PORT
        o.string '--host', 'Host name (default: 127.0.0.1)',
          default: '127.0.0.1'
        o.string '--home', 'Home directory (default: .)',
          default: Dir.pwd
        o.integer '--strength',
          "The strength of the score (default: #{Score::STRENGTH})",
          default: Score::STRENGTH
        o.integer '--threads',
          'How many threads to use for scores finding (default: 8)',
          default: 8
        o.bool '--standalone',
          'Never communicate with other nodes (mostly for testing)',
          default: false
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise '--invoice is mandatory' unless opts[:invoice]
      Zold::Front.set(:log, @log)
      Zold::Front.set(:logging, @log.debug?)
      FileUtils.mkdir_p(opts[:home])
      Zold::Front.set(:home, opts[:home])
      Zold::Front.set(
        :server_settings,
        Logger: WebrickLog.new(@log),
        AccessLog: []
      )
      if opts['standalone']
        remotes = Remotes::Empty.new
        @log.debug('Running in standalone mode!')
      else
        remotes = Remotes.new(File.join(opts[:home], 'zold-remotes'))
      end
      wallets = Wallets.new(File.join(opts[:home], 'zold-wallets'))
      Zold::Front.set(:wallets, wallets)
      Zold::Front.set(:remotes, remotes)
      copies = File.join(opts[:home], 'zold-copies')
      Zold::Front.set(:copies, copies)
      address = "#{opts[:host]}:#{opts[:port]}".downcase
      Zold::Front.set(:address, address)
      Zold::Front.set(
        :entrance, Entrance.new(wallets, remotes, copies, address, log: @log)
      )
      Zold::Front.set(:port, opts['bind-port'])
      invoice = opts[:invoice]
      unless invoice.include?('@')
        require_relative 'invoice'
        invoice = Invoice.new(wallets: wallets, log: @log).run(['invoice', invoice])
      end
      farm = Farm.new(invoice, log: @log)
      farm.start(
        opts[:host],
        opts[:port],
        threads: opts[:threads], strength: opts[:strength]
      )
      Zold::Front.set(:farm, farm)
      @log.debug('Starting up the web front...')
      begin
        Zold::Front.run!
      ensure
        farm.stop
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
