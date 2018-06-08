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
require 'concurrent'
require_relative '../version'
require_relative '../wallet'
require_relative '../log'
require_relative '../id'
require_relative '../http'
require_relative '../atomic_file'

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Web front
  class Front < Sinatra::Base
    configure do
      set :bind, '0.0.0.0'
      set :suppress_messages, true
      set :dump_errors, false
      set :start, Time.now
      set :lock, false
      set :show_exceptions, false
      set :server, 'webrick'
      set :ignore_score_weakness, false # to be injected at node.rb
      set :reboot, false # to be injected at node.rb
      set :home, nil? # to be injected at node.rb
      set :logging, true # to be injected at node.rb
      set :log, nil? # to be injected at node.rb
      set :address, nil? # to be injected at node.rb
      set :farm, nil? # to be injected at node.rb
      set :entrance, nil? # to be injected at node.rb
      set :wallets, nil? # to be injected at node.rb
      set :remotes, nil? # to be injected at node.rb
      set :copies, nil? # to be injected at node.rb
    end
    use Rack::Deflater

    before do
      name = "HTTP-#{Http::SCORE_HEADER}".upcase.tr('-', '_')
      header = request.env[name]
      return unless header
      if settings.remotes.all.empty?
        settings.log.debug("#{request.url}: we are in standalone mode, won't update remotes")
      end
      s = Score.parse_text(header)
      error(400, 'The score is invalid') unless s.valid?
      error(400, 'The score is weak') if s.strength < Score::STRENGTH && !settings.ignore_score_weakness
      if s.value > 3
        require_relative '../commands/remote'
        Remote.new(remotes: settings.remotes, log: settings.log).run(
          ['remote', 'add', s.host, s.port.to_s, '--force']
        )
      else
        settings.log.debug("#{request.url}: the score is too weak: #{s}")
      end
    end

    after do
      headers['Cache-Control'] = 'no-cache'
      headers['Connection'] = 'close'
      headers['X-Zold-Version'] = VERSION
      headers['Access-Control-Allow-Origin'] = '*'
      headers[Http::SCORE_HEADER] = score.reduced(16).to_s
    end

    get '/robots.txt' do
      content_type 'text/plain'
      'User-agent: *'
    end

    get '/version' do
      content_type 'text/plain'
      VERSION
    end

    get '/score' do
      content_type 'text/plain'
      score.to_s
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
      content_type 'application/json'
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h,
        pid: Process.pid,
        cpus: Concurrent.processor_count,
        uptime: `uptime`.strip,
        threads: "#{Thread.list.select { |t| t.status == 'run' }.count}/#{Thread.list.count}",
        wallets: settings.wallets.all.count,
        remotes: settings.remotes.all.count,
        farm: settings.farm.to_json,
        entrance: settings.entrance.to_json,
        date: `date  --iso-8601=seconds -u`.strip,
        hours_alive: ((Time.now - settings.start) / (60 * 60)).round(2),
        home: 'https://www.zold.io'
      )
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})} do
      id = Id.new(params[:id])
      wallet = settings.wallets.find(id)
      error 404 unless wallet.exists?
      content_type 'application/json'
      {
        version: VERSION,
        score: score.to_h,
        body: AtomicFile.new(wallet.path).read
      }.to_json
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      id = Id.new(params[:id])
      wallet = settings.wallets.find(id)
      request.body.rewind
      after = request.body.read.to_s
      before = wallet.exists? ? AtomicFile.new(wallet.path).read : ''
      if before == after
        status 304
        return
      end
      settings.log.info("Wallet #{id} is new: #{before.length}b != #{after.length}b")
      settings.entrance.push(id, after, sync: !params[:sync].nil?)
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h
      )
    end

    get '/remotes' do
      content_type 'application/json'
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h,
        all: settings.remotes.all
      )
    end

    not_found do
      status 404
      content_type 'text/plain'
      'Page not found'
    end

    error 400 do
      status 400
      content_type 'text/plain'
      env['sinatra.error'].message
    end

    error do
      status 503
      e = env['sinatra.error']
      content_type 'text/plain'
      "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end

    private

    def score
      best = settings.farm.best
      error 404 if best.empty?
      best[0]
    end
  end
end
