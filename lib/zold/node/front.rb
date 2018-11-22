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

STDOUT.sync = true

require 'eventmachine'
require 'thin'
require 'json'
require 'sinatra/base'
require 'concurrent'
require 'backtrace'
require 'zache'
require 'posix/spawn'
require_relative '../version'
require_relative '../size'
require_relative '../wallet'
require_relative '../age'
require_relative '../copies'
require_relative '../log'
require_relative '../tax'
require_relative '../id'
require_relative '../http'

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Web front
  class Front < Sinatra::Base
    configure do
      Thread.current.name = 'sinatra'
      set :bind, '0.0.0.0'
      set :suppress_messages, true
      set :start, Time.now
      set :lock, false
      set :show_exceptions, false
      set :server, :thin
      set :opts, nil # to be injected at node.rb
      set :log, nil # to be injected at node.rb
      set :trace, nil # to be injected at node.rb
      set :dump_errors, false # to be injected at node.rb
      set :protocol, PROTOCOL # to be injected at node.rb
      set :nohup_log, false # to be injected at node.rb
      set :home, nil # to be injected at node.rb
      set :logging, true # to be injected at node.rb
      set :logger, nil # to be injected at node.rb
      set :address, nil # to be injected at node.rb
      set :farm, nil # to be injected at node.rb
      set :metronome, nil # to be injected at node.rb
      set :entrance, nil # to be injected at node.rb
      set :wallets, nil # to be injected at node.rb
      set :remotes, nil # to be injected at node.rb
      set :copies, nil # to be injected at node.rb
      set :node_alias, nil # to be injected at node.rb
      set :zache, Zache.new
    end
    use Rack::Deflater

    before do
      Thread.current.thread_variable_set(:uri, request.url)
      Thread.current.thread_variable_set(:ip, request.ip)
      @start = Time.now
      if !settings.opts['halt-code'].empty? && params[:halt] && params[:halt] == settings.opts['halt-code']
        settings.log.error('Halt signal received, shutting the front end down...')
        Front.stop!
      end
      check_header(Http::NETWORK_HEADER) do |header|
        if header != settings.opts['network']
          error(400, "Network name mismatch at #{request.url}, #{request.ip} is in '#{header}', \
while #{settings.address} is in '#{settings.opts['network']}'")
        end
      end
      check_header(Http::PROTOCOL_HEADER) do |header|
        if header != settings.protocol.to_s
          error(400, "Protocol mismatch, you are in '#{header}', we are in '#{settings.protocol}'")
        end
      end
      check_header(Http::SCORE_HEADER) do |header|
        if settings.opts['standalone']
          settings.log.debug("#{request.url}: we are in standalone mode, won't update remotes")
        else
          s = Score.parse_text(header)
          error(400, 'The score is invalid') unless s.valid?
          error(400, 'The score is weak') if s.strength < Score::STRENGTH && !settings.opts['ignore-score-weakness']
          if settings.address == "#{s.host}:#{s.port}" && !settings.opts['ignore-score-weakness']
            error(400, 'Self-requests are prohibited')
          end
          require_relative '../commands/remote'
          begin
            Remote.new(remotes: settings.remotes, log: settings.log).run(
              ['remote', 'add', s.host, s.port.to_s, "--network=#{settings.opts['network']}", '--ignore-if-exists']
            )
          rescue StandardError => e
            error(400, e.message)
          end
        end
      end
    end

    # @todo #357:30min Test that the headers are being set correctly.
    #  Currently there are no tests at all that would verify the headers.
    after do
      headers['Cache-Control'] = 'no-cache'
      headers['X-Zold-Version'] = settings.opts['expose-version']
      headers[Http::PROTOCOL_HEADER] = settings.protocol.to_s
      headers['Access-Control-Allow-Origin'] = '*'
      headers[Http::SCORE_HEADER] = score.reduced(16).to_s
      headers['X-Zold-Thread'] = Thread.current.object_id.to_s
      unless @start.nil?
        if Time.now - @start > 1
          settings.log.info("Slow response to #{request.request_method} #{request.url} \
in #{Age.new(@start, limit: 1)}")
        end
        headers['X-Zold-Milliseconds'] = ((Time.now - @start) * 1000).round.to_s
      end
    end

    get '/robots.txt' do
      content_type('text/plain')
      'User-agent: *'
    end

    get '/version' do
      content_type('text/plain')
      settings.opts['expose-version']
    end

    get '/protocol' do
      content_type('text/plain')
      settings.protocol.to_s
    end

    get '/pid' do
      content_type('text/plain')
      Process.pid.to_s
    end

    get '/score' do
      content_type('text/plain')
      score.to_s
    end

    get '/trace' do
      content_type('text/plain')
      settings.trace.to_s
    end

    get '/nohup_log' do
      raise 'Run it with --nohup in order to see this log' if settings.nohup_log.nil?
      error(400, "Log not found at #{settings.nohup_log}") unless File.exist?(settings.nohup_log)
      response.headers['Content-Type'] = 'text/plain'
      response.headers['Content-Disposition'] = "attachment; filename='#{File.basename(settings.nohup_log)}'"
      IO.read(settings.nohup_log)
    end

    get '/favicon.ico' do
      if score.value >= 16
        redirect 'https://www.zold.io/images/logo-green.png'
      elsif score.value >= 4
        redirect 'https://www.zold.io/images/logo-orange.png'
      else
        redirect 'https://www.zold.io/images/logo-red.png'
      end
    end

    get '/' do
      content_type('application/json')
      pretty(
        version: settings.opts['expose-version'],
        alias: settings.node_alias,
        network: settings.opts['network'],
        protocol: settings.protocol,
        score: score.to_h,
        pid: Process.pid,
        processes: processes_count,
        cpus: settings.zache.get(:cpus) do
          Concurrent.processor_count
        end,
        memory: settings.zache.get(:memory, lifetime: 5 * 60) do
          require 'get_process_mem'
          GetProcessMem.new.bytes.to_i
        end,
        platform: RUBY_PLATFORM,
        load: settings.zache.get(:load, lifetime: 5 * 60) do
          require 'usagewatch_ext'
          Object.const_defined?('Usagewatch') ? Usagewatch.uw_load.to_f : 0.0
        end,
        threads: "#{Thread.list.select { |t| t.status == 'run' }.count}/#{Thread.list.count}",
        wallets: total_wallets,
        remotes: all_remotes.count,
        nscore: all_remotes.map { |r| r[:score] }.inject(&:+) || 0,
        farm: settings.farm.to_json,
        entrance: settings.entrance.to_json,
        date: Time.now.utc.iso8601,
        hours_alive: ((Time.now - settings.start) / (60 * 60)).round(2),
        home: 'https://www.zold.io'
      )
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})} do
      fetch('application/json') do |wallet|
        pretty(
          version: settings.opts['expose-version'],
          alias: settings.node_alias,
          protocol: settings.protocol,
          id: wallet.id.to_s,
          score: score.to_h,
          wallets: total_wallets,
          mtime: wallet.mtime.utc.iso8601,
          size: wallet.size,
          digest: wallet.digest,
          copies: Copies.new(File.join(settings.copies, wallet.id)).all.count,
          balance: wallet.balance.to_i,
          body: File.new(wallet.path).read
        )
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16}).json} do
      fetch('application/json') do |wallet|
        pretty(
          version: settings.opts['expose-version'],
          alias: settings.node_alias,
          protocol: settings.protocol,
          id: wallet.id.to_s,
          score: score.to_h,
          wallets: total_wallets,
          key: wallet.key.to_pub,
          mtime: wallet.mtime.utc.iso8601,
          digest: wallet.digest,
          balance: wallet.balance.to_i,
          txns: wallet.txns.count
        )
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/balance} do
      fetch { |w| w.balance.to_i.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/key} do
      fetch { |w| w.key.to_pub }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/mtime} do
      fetch { |w| w.mtime.utc.iso8601.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/size} do
      fetch { |w| w.size.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/age} do
      fetch { |w| w.age.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/age} do
      fetch { |w| w.age.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/txns} do
      fetch { |w| w.txns.count.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/debt} do
      fetch { |w| Tax.new(w).debt.to_i.to_s }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/digest} do
      fetch(&:digest)
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/mnemo} do
      fetch(&:mnemo)
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.txt} do
      fetch do |wallet|
        [
          wallet.network,
          wallet.protocol,
          wallet.id.to_s,
          wallet.key.to_pub,
          '',
          wallet.txns.map(&:to_text).join("\n"),
          '',
          '--',
          "Balance: #{wallet.balance.to_zld(8)} ZLD (#{wallet.balance.to_i} zents)",
          "Transactions: #{wallet.txns.count}",
          "Taxes: #{Tax.new(wallet).paid} paid, the debt is #{Tax.new(wallet).debt}",
          "File size: #{wallet.size} bytes (#{Copies.new(File.join(settings.copies, wallet.id)).all.count} copies)",
          "Modified: #{wallet.mtime.utc.iso8601} (#{Age.new(wallet.mtime.utc.iso8601)} ago)",
          "Digest: #{wallet.digest}"
        ].join("\n")
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.bin} do
      fetch { |w| IO.read(w.path) }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copies} do
      fetch do |wallet|
        copies = Copies.new(File.join(settings.copies, wallet.id))
        copies.load.map do |c|
          "#{c[:name]}: #{c[:host]}:#{c[:port]} #{c[:score]} #{c[:time].utc.iso8601}"
        end.join("\n") +
        "\n\n" +
        copies.all.map do |c|
          w = Wallet.new(c[:path])
          "#{c[:name]}: #{c[:score]} #{w.mnemo} \
#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}"
        end.join("\n")
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copy/(?<name>[0-9]+)} do
      fetch do |wallet|
        name = params[:name]
        copy = Copies.new(File.join(settings.copies, wallet.id)).all.find { |c| c[:name] == name }
        error 404 if copy.nil?
        IO.read(copy[:path])
      end
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      error(404, 'PUSH is disabled with --disable-push') if settings.opts['disable-fetch']
      request.body.rewind
      modified = settings.entrance.push(Id.new(params[:id]), request.body.read.to_s)
      if modified.empty?
        status(304)
        return
      end
      pretty(
        version: settings.opts['expose-version'],
        alias: settings.node_alias,
        score: score.to_h,
        wallets: total_wallets
      )
    end

    get '/remotes' do
      content_type('application/json')
      pretty(
        version: settings.opts['expose-version'],
        alias: settings.node_alias,
        score: score.to_h,
        all: all_remotes,
        mtime: settings.remotes.mtime.utc.iso8601
      )
    end

    get '/farm' do
      content_type('text/plain')
      settings.farm.to_text
    end

    get '/metronome' do
      content_type('text/plain')
      settings.metronome.to_text
    end

    get '/threads' do
      content_type('text/plain')
      [
        "Total threads: #{Thread.list.count}",
        Thread.list.map do |t|
          [
            "#{t.name}: status=#{t.status}; alive=#{t.alive?}",
            'Vars: ' + t.thread_variables.map { |v| "#{v}=\"#{t.thread_variable_get(v)}\"" }.join('; '),
            t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
          ].join("\n")
        end
      ].flatten.join("\n\n")
    end

    get '/ps' do
      content_type('text/plain')
      processes.join("\n")
    end

    not_found do
      status(404)
      content_type('text/plain')
      "Page not found: #{request.url}"
    end

    error 400 do
      status(400)
      content_type('text/plain')
      env['sinatra.error'] ? env['sinatra.error'].message : 'Invalid request'
    end

    error do
      status 503
      e = env['sinatra.error']
      content_type 'text/plain'
      headers['X-Zold-Error'] = e.message
      headers['X-Zold-Path'] = request.url
      settings.log.error(Backtrace.new(e).to_s)
      Backtrace.new(e).to_s
    end

    private

    def check_header(name)
      name = "HTTP-#{name}".upcase.tr('-', '_')
      header = request.env[name]
      return unless header
      yield header
    end

    # @todo #513:30min This method is temporarily disabled since it
    #  takes a lot of time (when the amount of wallets is big, like 40K). However,
    #  we must find a way to count them somehow faster.
    def total_wallets
      return 256 if settings.opts['network'] == Wallet::MAINET
      settings.wallets.all.count
    end

    def all_remotes
      settings.zache.get(:remotes, lifetime: settings.opts['network'] == Wallet::MAINET ? 60 : 0) do
        settings.remotes.all
      end
    end

    def processes_count
      settings.zache.get(:processes, lifetime: settings.opts['network'] == Wallet::MAINET ? 60 : 0) do
        processes.count
      end
    end

    def processes
      POSIX::Spawn::Child.new('ps', 'ax').out.split("\n").select { |t| t.include?('zold') }
    end

    def pretty(json)
      JSON.pretty_generate(json)
    end

    def score
      settings.zache.get(:score, lifetime: settings.opts['network'] == Wallet::MAINET ? 60 : 0) do
        b = settings.farm.best
        raise 'Score is empty, there is something wrong with the Farm!' if b.empty?
        b[0]
      end
    end

    def fetch(type = 'text/plain')
      error(404, 'FETCH is disabled with --disable-fetch') if settings.opts['disable-fetch']
      id = Id.new(params[:id])
      settings.wallets.acq(id) do |wallet|
        error(404, "Wallet ##{id} doesn't exist on the node") unless wallet.exists?
        content_type(type)
        yield wallet
      end
    end
  end
end
