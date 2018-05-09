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

require 'minitest/autorun'
require 'rack/test'
require 'tmpdir'
require_relative '../../lib/zold/key.rb'
require_relative '../../lib/zold/id.rb'
require_relative '../../lib/zold/amount.rb'
require_relative '../../lib/zold/wallet.rb'

home = Dir.pwd
temp = Dir.mktmpdir
FileUtils.chdir(temp)
require_relative '../../lib/zold/node/front.rb'
FileUtils.chdir(home)

class FrontTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Zold::Front.new
  end

  def test_renders_version
    get('/version')
    assert(last_response.ok?)
  end

  def test_robots_txt
    get('/robots.txt')
    assert(last_response.ok?)
  end

  def test_it_renders_home_page
    get('/')
    assert(last_response.ok?)
    assert(last_response.body.include?('zold'))
  end

  def test_fetches_score
    get('/score.json')
    assert(last_response.ok?)
    assert(last_response.body.include?('date'))
  end

  def test_pushes_a_wallet
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id::ROOT
      file = File.join(dir, "#{id}.xml")
      wallet = Zold::Wallet.new(file)
      wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
      put("/wallet/#{id}", File.read(file))
      assert(last_response.ok?, last_response.body)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(Zold::Amount.new(zld: 39.99), Zold::Id.new, key)
      put("/wallet/#{id}", File.read(file))
      assert(last_response.ok?, last_response.body)
    end
  end

  def test_pulls_a_wallet
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      file = File.join(dir, "#{id}.xml")
      wallet = Zold::Wallet.new(file)
      wallet.init(
        id, Zold::Key.new(file: 'fixtures/id_rsa.pub')
      )
      put("/wallet/#{id}", File.read(file))
      assert(last_response.ok?, last_response.body)
      get("/wallet/#{id}.json")
      assert(last_response.ok?, last_response.body)
      File.write(file, JSON.parse(last_response.body)['body'])
      assert wallet.balance.zero?
    end
  end

  def test_pulls_an_absent_wallet
    get('/wallets/ffffeeeeddddcccc')
    assert(last_response.status == 404)
  end
end
