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

require 'slop'
require 'json'
require 'sinatra/base'
require 'webrick'

require_relative 'farm'
require_relative '../version'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../log'
require_relative '../remotes'
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
      set :logging, true
      set :dump_errors, true
      set :start, Time.now
      set :lock, false
      set :log, Log.new
      set :show_exceptions, false
      set :home, Dir.pwd
      set :farm, Farm.new
      set :server, 'webrick'
    end

    before do
      if request.env[Http::SCORE_HEADER] && !settings.remotes.empty?
        s = Score.parse(request.env[Http::SCORE_HEADER])
        error(400, 'The score is invalid') unless s.valid?
        error(400, 'The score is weak') if s.strength < Score::STRENGTH
        settings.remotes.add(s.host, s.port) if s.value > 3
      end
    end

    after do
      headers['Cache-Control'] = 'no-cache'
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
        wallets: wallets.all.count,
        farm: settings.farm.to_json,
        date: `date  --iso-8601=seconds -u`.strip,
        age: (Time.now - settings.start) / (60 * 60),
        home: 'https://www.zold.io'
      )
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})} do
      id = Id.new(params[:id])
      wallet = wallets.find(id)
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
      wallet = wallets.find(id)
      request.body.rewind
      cps = copies(id)
      cps.add(request.body.read, 'remote', Remotes::PORT, 0)
      require_relative '../commands/fetch'
      Zold::Fetch.new(
        remotes: settings.remotes, copies: cps.root,
        log: settings.log
      ).run([id.to_s])
      require_relative '../commands/merge'
      Zold::Merge.new(
        wallets: wallets, copies: cps.root,
        log: settings.log
      ).run([id.to_s])
      cps.remove('remote', Remotes::PORT)
      "Success, #{wallet.id} balance is #{wallet.balance}"
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

    def copies(id)
      Copies.new(File.join(settings.home, ".zoldata/copies/#{id}"))
    end

    def wallets
      Wallets.new(settings.home)
    end

    def score
      best = settings.farm.best
      error 404 if best.empty?
      best[0]
    end
  end
end
