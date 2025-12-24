# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

$stdout.sync = true

require 'get_process_mem'
require 'thin'
require 'haml'
require 'shellwords'
require 'json'
require 'digest'
require 'sinatra/base'
require 'concurrent'
require 'backtrace'
require 'zache'
require 'total'
require_relative '../version'
require_relative '../size'
require_relative '../wallet'
require_relative '../age'
require_relative '../copies'
require 'loog'
require_relative '../dir_items'
require_relative '../tax'
require_relative '../id'
require_relative '../http'
require_relative 'soft_error'

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Web front
  class Front < Sinatra::Base
    # The minimum score required in order to recognize a requester
    # as a valuable node and add it to the list of remotes.
    MIN_SCORE = 4

    configure do
      Haml::Options.defaults[:format] = :xhtml
      set :views, proc { File.expand_path(File.join(__dir__, '../../../views')) }
      Thread.current.name = 'sinatra'
      set :bind, '0.0.0.0'
      set :suppress_messages, true
      set :start, Time.now
      set :lock, false
      set :show_exceptions, false
      set :raise_errors, false
      set :server, :thin
      set :opts, nil # to be injected at node.rb
      set :log, nil # to be injected at node.rb
      set :ledger, nil # to be injected at node.rb
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
      set :zache, nil # to be injected at node.rb
      set :async_dir, nil # to be injected at node.rb
      set :journal_dir, nil # to be injected at node.rb
    end
    use Rack::Deflater

    before do
      Thread.current.name = "#{request.request_method}:#{request.url}"
      Thread.current.thread_variable_set(:uri, request.url)
      error(400, 'Can\'t detect your IP') if request.ip.nil? || request.ip.empty?
      Thread.current.thread_variable_set(:ip, request.ip)
      @start = Time.now
      if !settings.opts['halt-code'].empty? && params[:halt] && params[:halt] == settings.opts['halt-code']
        settings.log.info('Halt signal received, shutting the front end down...')
        Thread.start do
          sleep 0.1 # to let the current request finish and close the socket
          Front.stop!
        end
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
          s = Score.parse(header)
          error(400, 'The score is invalid') unless s.valid?
          error(400, 'The score is expired') if s.expired?
          error(400, 'The score is weak') if s.strength < Score::STRENGTH && !settings.opts['ignore-score-weakness']
          return if s.value < Front::MIN_SCORE && !settings.opts['ignore-score-weakness']
          if settings.address == "#{s.host}:#{s.port}" && !settings.opts['ignore-score-weakness']
            error(400, 'Self-requests are prohibited')
          end
          add_new_remote(s)
        end
      end
    end

    # @todo #357:30min Test that the headers are being set correctly.
    #  Currently there are no tests at all that would verify the headers.
    after do
      headers['Cache-Control'] = 'no-cache'
      headers['X-Zold-Path'] = request.url
      headers['X-Zold-Version'] = settings.opts['expose-version']
      headers['X-Zold-Repo'] = Zold::REPO
      headers[Http::PROTOCOL_HEADER] = settings.protocol.to_s
      headers['Access-Control-Allow-Origin'] = '*'
      headers[Http::SCORE_HEADER] = score.reduced(Front::MIN_SCORE).to_s
      headers['X-Zold-Thread'] = Thread.current.object_id.to_s
      unless @start.nil?
        if Time.now - @start > 1
          settings.log.debug("Slow response to #{request.request_method} #{request.url} \
from #{request.ip} in #{Age.new(@start, limit: 1)}")
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
      File.read(settings.nohup_log)
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
        repo: Zold::REPO,
        version: settings.opts['expose-version'],
        alias: settings.node_alias,
        network: settings.opts['network'],
        protocol: settings.protocol,
        score: score.to_h,
        pid: Process.pid,
        processes: processes_count,
        checksum: checksum,
        cpus: settings.zache.get(:cpus) do
          Concurrent.processor_count
        end,
        memory: settings.zache.get(:memory, lifetime: settings.opts['no-cache'] ? 0 : 60) do
          mem = GetProcessMem.new.bytes.to_i
          if mem > settings.opts['oom-limit'] * 1024 * 1024 &&
            !settings.opts['skip-oom'] && !settings.opts['never-reboot']
            settings.log.error("We are too big in memory (#{Size.new(mem)}), quitting; \
use --skip-oom to never quit or --memory-dump to print the entire memory usage summary on exit; \
this is not a normal behavior, you may want to report a bug to our GitHub repository")
            Front.stop!
          end
          mem
        end,
        platform: RUBY_PLATFORM,
        load: settings.zache.get(:load, lifetime: settings.opts['no-cache'] ? 0 : 60) do
          # doesn't work with Ruby 3.0+
          # require 'usagewatch_ext'
          # Object.const_defined?('Usagewatch') ? Usagewatch.uw_load.to_f : 0.0
          0.0
        end,
        total_mem: total_mem,
        threads: "#{Thread.list.count { |t| t.status == 'run' }}/#{Thread.list.count}",
        wallets: total_wallets,
        journal: DirItems.new(settings.journal_dir).fetch.count,
        remotes: all_remotes.count,
        nscore: all_remotes.sum { |r| r[:score] } || 0,
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
          mtime: wallet.mtime.utc.iso8601,
          age: wallet.age.to_s,
          size: wallet.size,
          digest: wallet.digest,
          copies: Copies.new(File.join(settings.copies, wallet.id)).all.count,
          balance: wallet.balance.to_i,
          txns: wallet.txns.count,
          taxes: Tax.new(wallet).paid.to_i,
          debt: Tax.new(wallet).debt.to_i
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

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/txns.json} do
      fetch('application/json') { |w| pretty(w.txns.map(&:to_json)) }
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
          "File size: #{Size.new(wallet.size)}/#{wallet.size}, \
#{Copies.new(File.join(settings.copies, wallet.id)).all.count} copies",
          "Modified: #{wallet.mtime.utc.iso8601} (#{Age.new(wallet.mtime.utc.iso8601)} ago)",
          "Digest: #{wallet.digest}"
        ].join("\n")
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.html} do
      fetch('text/html') do |wallet|
        haml(
          :wallet,
          layout: :layout,
          locals: {
            title: wallet.id.to_s,
            description: "Zold wallet #{wallet.id} at #{settings.address}",
            wallet: wallet
          }
        )
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.bin} do
      fetch { |w| send_file(w.path) }
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copies} do
      fetch do |wallet|
        copies = Copies.new(File.join(settings.copies, wallet.id))
        [
          copies.load.map do |c|
            "#{c[:name]}: #{c[:host]}:#{c[:port]} #{c[:score]} #{c[:time].utc.iso8601}"
          end.join("\n"),
          "\n\n",
          copies.all.map do |c|
            w = Wallet.new(c[:path])
            "#{c[:name]}: #{c[:score]} #{w.mnemo} \
#{Size.new(File.size(c[:path]))}/#{Age.new(File.mtime(c[:path]))}"
          end.join("\n")
        ].join
      end
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})/copy/(?<name>[0-9]+)} do
      fetch do |wallet|
        name = params[:name]
        copy = Copies.new(File.join(settings.copies, wallet.id)).all.find { |c| c[:name] == name }
        error 404 if copy.nil?
        File.read(copy[:path])
      end
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      error(404, 'PUSH is disabled with --disable-push') if settings.opts['disable-fetch']
      id = Id.new(params[:id])
      ban(id)
      request.body.rewind
      modified = settings.entrance.push(id, request.body.read.to_s)
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

    get '/wallets' do
      content_type('text/plain')
      settings.wallets.all.map(&:to_s).join("\n")
    end

    get '/remotes' do
      content_type('application/json')
      pretty(
        version: settings.opts['expose-version'],
        repo: Zold::REPO,
        alias: settings.node_alias,
        score: score.to_h,
        all: all_remotes,
        mtime: settings.remotes.mtime.utc.iso8601
      )
    end

    get '/ledger' do
      content_type('text/plain')
      File.exist?(settings.ledger) ? File.read(settings.ledger) : ''
    end

    get '/ledger.json' do
      content_type('application/json')
      pretty(
        (File.exist?(settings.ledger) ? File.read(settings.ledger).split("\n") : []).map do |t|
          parts = t.split(';')
          {
            found: parts[0],
            id: parts[1].to_i,
            date: parts[2],
            source: parts[3],
            target: parts[4],
            amount: parts[5].to_i,
            prefix: parts[6],
            details: parts[7]
          }
        end
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
            "Vars: #{t.thread_variables.map { |v| "#{v}=\"#{t.thread_variable_get(v)}\"" }.join('; ')}",
            t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
          ].join("\n")
        end
      ].flatten.join("\n\n")
    end

    get '/ps' do
      content_type('text/plain')
      processes.join("\n")
    end

    get '/queue' do
      content_type('text/plain')
      DirItems.new(settings.async_dir).fetch.grep(/^[0-9a-f]{16}-/).map do |f|
        Wallet.new(File.join(settings.async_dir, f)).mnemo
      rescue Errno::ENOENT
        f
      end.join("\n")
    end

    get '/journal' do
      content_type('text/html')
      haml(
        :journal,
        layout: :layout,
        locals: {
          title: '/journal',
          description: 'The journal',
          id: params[:id],
          files: DirItems.new(settings.journal_dir).fetch.sort.reverse.take(256).select do |f|
            !params[:id] || f.include?(params[:id])
          end,
          dir: settings.journal_dir
        }
      )
    end

    get '/journal/item' do
      content_type('text/plain')
      file = File.join(settings.journal_dir, params[:id])
      error(404, "Journal item not found at #{file}") unless File.exist?(file)
      File.read(file)
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
      if e.is_a?(SoftError)
        settings.log.info("#{request.ip}:#{request.request_method}:#{request.url}: #{e.message}")
      else
        settings.log.error(Backtrace.new(e).to_s)
      end
      if e.is_a?(Errno::ENOMEM) && !settings.opts['skip-oom']
        settings.log.error("We are running out of memory (#{Size.new(GetProcessMem.new.bytes.to_i)}), \
time to stop; use --skip-oom to never quit")
        Front.stop!
      end
      Backtrace.new(e).to_s
    end

    private

    def check_header(name)
      name = "HTTP-#{name}".upcase.tr('-', '_')
      header = request.env[name]
      return unless header
      yield header
    end

    def total_mem
      settings.zache.get(:total_mem, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        Total::Mem.new.bytes
      rescue Total::CantDetect => e
        settings.log.error(e.message)
        0
      end
    end

    def total_wallets
      settings.zache.get(:wallets, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        settings.wallets.count
      end
    end

    def checksum
      settings.zache.get(:checksum, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        Digest::MD5.hexdigest(
          Dir[File.join(__dir__, '../**/*')]
            .reject { |f| File.directory?(f) }
            .map { |f| File.read(f) }
            .join
        )
      end
    end

    def all_remotes
      settings.zache.get(:remotes, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        settings.remotes.all
      end
    end

    def processes_count
      settings.zache.get(:processes, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        processes.count
      end
    end

    def processes
      `ps ax`.split("\n").select { |t| t.include?('zold') }
    end

    def pretty(json)
      JSON.pretty_generate(json)
    end

    def score
      settings.zache.get(:score, lifetime: settings.opts['no-cache'] ? 0 : 60) do
        b = settings.farm.best
        raise 'Score is empty, there is something wrong with the Farm!' if b.empty?
        b[0]
      end
    end

    def ban(id)
      return unless Id::BANNED.include?(id.to_s)
      error(404, "The wallet #{id} is banned")
    end

    def fetch(type = 'text/plain')
      error(404, 'FETCH is disabled with --disable-fetch') if settings.opts['disable-fetch']
      id = Id.new(params[:id])
      ban(id)
      settings.wallets.acq(id) do |wallet|
        error(404, "Wallet ##{id} doesn't exist on the node") unless wallet.exists?
        content_type(type)
        yield wallet
      end
    end

    def add_new_remote(score)
      all = settings.remotes.all
      return if all.count > Remotes::MAX_NODES && all.none? { |r| r[:errors] > Remotes::TOLERANCE }
      begin
        require_relative '../commands/remote'
        Remote.new(remotes: settings.remotes, log: settings.log).run(
          [
            'remote', 'add', score.host, score.port.to_s,
            "--network=#{Shellwords.escape(settings.opts['network'])}", '--ignore-if-exists'
          ] + (settings.opts['ignore-score-weakness'] ? ['--skip-ping'] : [])
        )
      rescue StandardError => e
        error(400, e.message)
      end
    end
  end
end
