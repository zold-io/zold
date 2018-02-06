# Copyright (c) 2018 Zerocracy, Inc.
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
require_relative '../lib/zold/key.rb'

# Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
class TestKey < Minitest::Test
  def test_reads_public_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    assert key.to_pub.start_with?('MIICI')
    assert key.to_pub.end_with?('EAAQ==')
    assert !key.to_pub.include?("\n")
    assert Zold::Key.new(text: key.to_pub).to_pub.start_with?('MIICI')
  end

  def test_reads_private_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa')
    assert key.to_pub.start_with?('MIIJJ')
    assert key.to_pub.end_with?('Sg==')
  end

  def test_signs_and_verifies
    pub = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    pvt = Zold::Key.new(file: 'fixtures/id_rsa')
    text = 'How are you, my friend?'
    signature = pvt.sign(text)
    assert pub.verify(signature, text)
  end

  def test_signs_and_verifies_with_random_key
    Dir.mktmpdir 'test' do |dir|
      key = OpenSSL::PKey::RSA.new(2048)
      file = File.join(dir, 'temp')
      File.write(file, key.public_key.to_s)
      pub = Zold::Key.new(file: file)
      File.write(file, key.to_s)
      pvt = Zold::Key.new(file: file)
      text = 'How are you doing, dude?'
      signature = pvt.sign(text)
      assert pub.verify(signature, text)
    end
  end
end
