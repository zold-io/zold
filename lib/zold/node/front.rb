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

require 'haml'
require 'slop'
require 'json'
require 'sinatra/base'

require_relative 'farm'
require_relative '../version'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../id'
require_relative '../commands/show'

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Web front
  class Front < Sinatra::Base
    configure do
      Haml::Options.defaults[:format] = :xhtml
      set :lock, Mutex.new
      set :views, (proc { File.join(root, '../../../views') })
      set :show_exceptions, false
      set :wallets, Wallets.new(Dir.pwd)
      set :farm, Farm.new
    end

    get '/' do
      redirect '/index.html'
    end

    get '/index.html' do
      haml :index, layout: :layout, locals: {
        title: 'zold',
        total: settings.wallets.all.count
      }
    end

    get '/robots.txt' do
      'User-agent: *'
    end

    get '/favicon.ico' do
      redirect 'https://www.zold.io/logo.png'
    end

    get '/version' do
      VERSION
    end

    get '/score.json' do
      content_type 'application/json'
      {
        'score': score.to_h
      }.to_json
    end

    get '/score.txt' do
      content_type 'text/plain'
      score.to_s
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.json} do
      id = Id.new(params[:id])
      wallet = settings.wallets.find(id)
      error 404 unless wallet.exists?
      content_type 'application/json'
      {
        'score': score.to_h,
        'body': File.read(wallet.path)
      }.to_json
    end

    get %r{/wallet/(?<id>[A-Fa-f0-9]{16})\.txt} do
      id = Id.new(params[:id])
      wallet = settings.wallets.find(id)
      error 404 unless wallet.exists?
      content_type 'text/plain'
      File.read(wallet.path)
    end

    put %r{/wallet/(?<id>[A-Fa-f0-9]{16})/?} do
      settings.lock.synchronize do
        id = Id.new(params[:id])
        wallet = settings.wallets.find(id)
        temp = before = nil
        if wallet.exists?
          before = wallet.version
          temp = Tempfile.new('z')
          FileUtils.cp(wallet.path, temp)
        end
        begin
          request.body.rewind
          File.write(wallet.path, request.body.read)
          unless before.nil?
            after = wallet.version
            error 403 if after < before
          end
        ensure
          unless temp.nil?
            FileUtils.cp(temp, wallet.path)
            temp.unlink
          end
        end
      end
    end

    not_found do
      status 404
      haml :not_found, layout: :layout, locals: {
        title: 'Page not found'
      }
    end

    error do
      status 503
      e = env['sinatra.error']
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
