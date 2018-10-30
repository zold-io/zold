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

require 'json'
require 'sinatra/base'
require 'webrick'
require 'cachy'
require 'moneta'
require 'get_process_mem'
require 'diffy'
require 'usagewatch_ext'
require 'concurrent'
require 'backtrace'
require_relative '../version'
require_relative '../size'
require_relative '../wallet'
require_relative '../age'
require_relative '../copies'
require_relative '../log'
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
      Cachy.cache_store = Moneta.new(:Memory)
      set :bind, '0.0.0.0'
      set :suppress_messages, true
      set :start, Time.now
      set :lock, false
      set :show_exceptions, false
      set :server, :puma
      set :log, nil? # to be injected at node.rb
      set :trace, nil? # to be injected at node.rb
      set :halt, '' # to be injected at node.rb
      set :dump_errors, false # to be injected at node.rb
      set :version, VERSION # to be injected at node.rb
      set :protocol, PROTOCOL # to be injected at node.rb
      set :ignore_score_weakness, false # to be injected at node.rb
      set :reboot, false # to be injected at node.rb
      set :nohup_log, false # to be injected at node.rb
      set :home, nil? # to be injected at node.rb
      set :logging, true # to be injected at node.rb
      set :logger, nil? # to be injected at node.rb
      set :address, nil? # to be injected at node.rb
      set :farm, nil? # to be injected at node.rb
      set :metronome, nil? # to be injected at node.rb
      set :entrance, nil? # to be injected at node.rb
      set :network, 'test' # to be injected at node.rb
      set :wallets, nil? # to be injected at node.rb
      set :remotes, nil? # to be injected at node.rb
      set :copies, nil? # to be injected at node.rb
      set :node_alias, nil? # to be injected at node.rb
    end
    use Rack::Deflater

    before do
      if !settings.halt.empty? && params[:halt] && params[:halt] == settings.halt
        settings.log.error('Halt signal received, shutting the front end down...')
        Front.stop!
      end
      check_header(Http::NETWORK_HEADER) do |header|
        if header != settings.network
          error(400, "Network name mismatch at #{request.url}, #{request.ip} is in '#{header}', \
while #{settings.address} is in '#{settings.network}'")
        end
      end
      check_header(Http::PROTOCOL_HEADER) do |header|
        if header != settings.protocol.to_s
          error(400, "Protocol mismatch, you are in '#{header}', we are in '#{settings.protocol}'")
        end
      end
      check_header(Http::SCORE_HEADER) do |header|
        if settings.remotes.all.empty?
          settings.log.debug("#{request.url}: we are in standalone mode, won't update remotes")
        end
        s = Score.parse_text(header)
        error(400, 'The score is invalid') unless s.valid?
        error(400, 'The score is weak') if s.strength < Score::STRENGTH && !settings.ignore_score_weakness
        if settings.address == "#{s.host}:#{s.port}" && !settings.ignore_score_weakness
          error(400, 'Self-requests are prohibited')
        end
        require_relative '../commands/remote'
        cmd = Remote.new(remotes: settings.remotes, log: settings.log)
        begin
          cmd.run(['remote', 'add', s.host, s.port.to_s, "--network=#{settings.network}"])
        rescue StandardError => e
          error(400, e.message)
        end
      end
      @start = Time.now
    end

    # @todo #357:30min Test that the headers are being set correctly.
    #  Currently there are no tests at all that would verify the headers.
    after do
      headers['Cache-Control'] = 'no-cache'
      headers['X-Zold-Version'] = settings.version
      headers[Http::PROTOCOL_HEADER] = settings.protocol.to_s
      headers['Access-Control-Allow-Origin'] = '*'
      headers[Http::SCORE_HEADER] = score.reduced(16).to_s
      headers['X-Zold-Thread'] = Thread.current.name.to_s
      headers['X-Zold-Milliseconds'] = ((Time.now - @start) * 1000).round.to_s
    end

    get '/robots.txt' do
      content_type('text/plain')
      'User-agent: *'
    end

    get '/version' do
      content_type('text/plain')
      settings.version
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
      JSON.pretty_generate(
        version: settings.version,
        alias: settings.node_alias,
        network: settings.network,
        protocol: settings.protocol,
        score: score.to_h,
        pid: Process.pid,
        cpus: Cachy.cache(:a_cpus) { Concurrent.processor_count },
        memory: GetProcessMem.new.bytes.to_i,
        platform: RUBY_PLATFORM,
        load: Cachy.cache(:a_load, expires_in: 5 * 60) { Usagewatch.uw_load.to_f },
        threads: "#{Thread.list.select { |t| t.status == 'run' }.count}/#{Thread.list.count}",
        wallets: Cachy.cache(:a_wallets, expires_in: 5 * 60) { settings.wallets.all.count },
        remotes: settings.remotes.all.count,
        nscore: settings.remotes.all.map { |r| r[:score] }.inject(&:+) || 0,
        farm: settings.farm.to_json,
        entrance: settings.entrance.to_json,
        date: Time.now.utc.iso8601,
        hours_alive: ((Time.now - settings.start) / (60 * 60)).round(2),
        home: 'https://www.zold.io'
      )
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type('application/json')
        JSON.pretty_generate(
          version: settings.version,
          alias: settings.node_alias,
          protocol: settings.protocol,
          id: wallet.id.to_s,
          score: score.to_h,
          wallets: settings.wallets.all.count,
          mtime: wallet.mtime.utc.iso8601,
          size: File.size(wallet.path),
          digest: wallet.digest,
          copies: Copies.new(File.join(settings.copies, id)).all.count,
          balance: wallet.balance.to_i,
          body: File.new(wallet.path).read
        )
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16}).json} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type('application/json')
        JSON.pretty_generate(
          version: settings.version,
          alias: settings.node_alias,
          protocol: settings.protocol,
          id: wallet.id.to_s,
          score: score.to_h,
          wallets: settings.wallets.all.count,
          key: wallet.key.to_pub,
          mtime: wallet.mtime.utc.iso8601,
          digest: wallet.digest,
          balance: wallet.balance.to_i,
          txns: wallet.txns.count
        )
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/balance} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
        wallet.balance.to_i.to_s
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/key} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
        wallet.key.to_pub
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/mtime} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
        wallet.mtime.utc.iso8601.to_s
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/digest} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
        wallet.digest
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.txt} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
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
          "File size: #{File.size(wallet.path)} bytes (#{Copies.new(File.join(settings.copies, id)).all.count} copies)",
          "Modified: #{wallet.mtime.utc.iso8601} (#{Age.new(wallet.mtime.utc.iso8601)} ago)",
          "Digest: #{wallet.digest}"
        ].join("\n")
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.bin} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do |wallet|
        content_type 'text/plain'
        IO.read(wallet.path)
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copies} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      copy_of(id) do
        content_type 'text/plain'
        copies = Copies.new(File.join(settings.copies, id))
        copies.load.map do |c|
          "#{c[:name]}: #{c[:host]}:#{c[:port]} #{c[:score]} #{c[:time].utc.iso8601}"
        end.join("\n") +
        "\n\n" +
        copies.all.map do |c|
          w = Wallet.new(c[:path])
          "#{c[:name]}: #{c[:score]} #{w.balance}/#{w.txns.count}t/\
#{w.digest[0, 6]}/#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}"
        end.join("\n")
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copy/(?<name>[0-9]+)} do
      error(404, 'FETCH is disabled with --disable-fetch') if settings.disable_fetch
      id = Id.new(params[:id])
      name = params[:name]
      copy_of(id) do
        copy = Copies.new(File.join(settings.copies, id)).all.find { |c| c[:name] == name }
        error 404 if copy.nil?
        content_type 'text/plain'
        IO.read(copy[:path])
      end
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      error(404, 'PUSH is disabled with --disable-push') if settings.disable_fetch
      request.body.rewind
      modified = settings.entrance.push(Id.new(params[:id]), request.body.read.to_s)
      if modified.empty?
        status(304)
        return
      end
      JSON.pretty_generate(
        version: settings.version,
        alias: settings.node_alias,
        score: score.to_h,
        wallets: settings.wallets.all.count
      )
    end

    get '/remotes' do
      content_type('application/json')
      JSON.pretty_generate(
        version: settings.version,
        alias: settings.node_alias,
        score: score.to_h,
        all: settings.remotes.all,
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
            t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
          ].join("\n")
        end
      ].flatten.join("\n\n")
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

    def score
      best = Cachy.cache(:a_score, expires_in: 60) { settings.farm.best }
      raise 'Score is empty, there is something wrong with the Farm!' if best.empty?
      best[0]
    end

    def copy_of(id)
      Tempfile.open([id.to_s, Wallet::EXT]) do |f|
        settings.wallets.find(id) do |wallet|
          error(404, "Wallet ##{id} doesn't exist on the node") unless wallet.exists?
          IO.write(f, IO.read(wallet.path))
        end
        yield Wallet.new(f.path)
      end
    end
  end
end
