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

require 'minitest/autorun'
require 'tmpdir'
require 'uri'
require 'webmock/minitest'
require 'zold/score'
require 'random-port'
require_relative 'test__helper'
require_relative '../lib/zold/http'
require_relative '../lib/zold/verbose_thread'

# Http test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestHttp < Zold::Test
  def test_pings_broken_uri
    stub_request(:get, 'http://bad-host/').to_return(status: 500)
    res = Zold::Http.new(uri: 'http://bad-host/').get
    assert_equal(500, res.status)
    assert_equal('', res.body)
  end

  def test_pings_with_exception
    stub_request(:get, 'http://exception/').to_return { raise 'Intentionally' }
    res = Zold::Http.new(uri: 'http://exception/').get
    assert_equal(599, res.status)
    assert(res.body.include?('Intentionally'))
    assert(!res.headers['nothing'])
  end

  def test_pings_live_uri
    stub_request(:get, 'http://good-host/').to_return(status: 200)
    res = Zold::Http.new(uri: 'http://good-host/').get
    assert_equal(200, res.status)
  end

  def test_sends_valid_network_header
    stub_request(:get, 'http://some-host-1/')
      .with(headers: { 'X-Zold-Network' => 'xyz' })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-1/', network: 'xyz').get
    assert_equal(200, res.status)
  end

  def test_sends_valid_protocol_header
    stub_request(:get, 'http://some-host-2/')
      .with(headers: { 'X-Zold-Protocol' => Zold::PROTOCOL })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-2/').get
    assert_equal(200, res.status)
  end

  def test_terminates_on_timeout
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          server.accept
          sleep 400
        end
      end
      sleep 0.25
      res = Zold::Http.new(uri: "http://127.0.0.1:#{port}/").get(timeout: 0.1)
      assert_equal(0, res.status, res)
      thread.kill
      thread.join
    end
  end

  def test_doesnt_terminate_on_long_call
    WebMock.allow_net_connect!
    RandomPort::Pool::SINGLETON.acquire do |port|
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          client = server.accept
          client.puts("HTTP/1.1 200 OK\nContent-Length: 4\n\n")
          sleep 1
          client.puts('Good')
          client.close
        end
      end
      sleep 0.25
      res = Zold::Http.new(uri: "http://127.0.0.1:#{port}/").get(timeout: 2)
      assert_equal(200, res.status, res)
      thread.kill
      thread.join
    end
  end

  # @todo #444:30min It's obvious that the test works (I can see that in
  #  the console, but for some weird reason it doesn't work in Minitest. Try
  #  to run it: ruby test/test_http.rb -n test_sends_correct_http_headers
  #  If fails because of PUT HTTP request timeout. Let's find the problem,
  #  fix it, and un-skip the test.
  def test_sends_correct_http_headers
    skip
    WebMock.allow_net_connect!
    body = ''
    RandomPort::Pool::SINGLETON.acquire do |port|
      thread = Thread.start do
        Zold::VerboseThread.new(test_log).run do
          server = TCPServer.new(port)
          socket = server.accept
          loop do
            line = socket.gets
            break if line.nil?
            test_log.info(line.inspect)
            body += line
          end
          socket.print("HTTP/1.1 200 OK\r\n")
          socket.print("Content-Length: 4\r\n")
          socket.print("\r\n")
          socket.print('Done')
          socket.close
        end
      end
      res = Zold::Http.new(uri: "http://127.0.0.1:#{port}/").put('how are you?')
      assert_equal(200, res.status, res)
      assert(body.include?('Content-Length: 12'), body)
      assert(body.include?('Content-Type: text/plain'))
      headers = body.split("\n").select { |t| t =~ /^[a-zA-Z-]+:.+$/ }
      assert_equal(headers.count, headers.uniq.count)
      thread.kill
      thread.join
    end
  end

  def test_sends_valid_version_header
    stub_request(:get, 'http://some-host-3/')
      .with(headers: { 'X-Zold-Version' => Zold::VERSION })
      .to_return(status: 200)
    res = Zold::Http.new(uri: 'http://some-host-3/').get
    assert_equal(200, res.status, res)
  end
end
