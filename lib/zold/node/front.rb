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
require 'semantic'
require_relative '../version'
require_relative '../wallet'
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
      set :bind, '0.0.0.0'
      set :suppress_messages, true
      set :dump_errors, true
      set :start, Time.now
      set :lock, false
      set :show_exceptions, false
      set :server, 'webrick'
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

    before do
      if request.env[Http::VERSION_HEADER] &&
        Semantic::Version.new(VERSION) < Semantic::Version.new(request.env[Http::VERSION_HEADER]) &&
        settings.reboot
        exit(0)
      end
      return unless request.env[Http::SCORE_HEADER]
      return unless settings.remotes.empty?
      s = Score.parse(request.env[Http::SCORE_HEADER])
      error(400, 'The score is invalid') unless s.valid?
      settings.remotes.add(s.host, s.port) if s.value > 3
    end

    after do
      headers['Cache-Control'] = 'no-cache'
      headers['Connection'] = 'close'
      headers['X-Zold-Version'] = VERSION
    end

    get '/robots.txt' do
      'User-agent: *'
    end

    get '/favicon.ico' do
      redirect 'https://www.zold.io/logo.png'
    end

    get '/' do
      content_type 'application/json'
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h,
        uptime: `uptime`.strip,
        wallets: settings.wallets.all.count,
        remotes: settings.remotes.all.count,
        farm: settings.farm.to_json,
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
        body: File.read(wallet.path)
      }.to_json
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      id = Id.new(params[:id])
      wallet = settings.wallets.find(id)
      request.body.rewind
      body = request.body.read
      if wallet.exists? && File.read(wallet.path) == body
        status 304
        return
      end
      modified = settings.entrance.push(id, body)
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h,
        balance: wallet.balance,
        modified: modified.count
      )
    end

    get '/remotes' do
      content_type 'application/json'
      JSON.pretty_generate(
        version: VERSION,
        score: score.to_h,
        all: settings.remotes.all.map do |r|
          {
            host: r[:host],
            port: r[:port]
          }
        end
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
