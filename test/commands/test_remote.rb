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
require 'tmpdir'
require 'webmock/minitest'
require_relative '../../lib/zold/wallets.rb'
require_relative '../../lib/zold/remotes.rb'
require_relative '../../lib/zold/key.rb'
require_relative '../../lib/zold/score.rb'
require_relative '../../lib/zold/commands/remote.rb'

# REMOTE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemote < Minitest::Test
  def test_updates_remote
    Dir.mktmpdir 'test' do |dir|
      remotes = Zold::Remotes.new(File.join(dir, 'a/b/c/remotes'))
      cmd = Zold::Remote.new(remotes: remotes)
      cmd.run(['clean'])
      cmd.run(%w[add localhost 1])
      stub_request(:get, 'http://localhost:1/score.json').to_return(
        status: 200,
        body: {
          'score': Zold::Score.new(Time.now, 'localhost', 80).to_h
        }.to_json
      )
      cmd.run(%w[add localhost 2])
      stub_request(:get, 'http://localhost:2/score.json').to_return(
        status: 404
      )
      assert_equal(remotes.all.count, 2)
      cmd.run(['update'])
      assert_equal(1, remotes.all.count)
    end
  end
end
