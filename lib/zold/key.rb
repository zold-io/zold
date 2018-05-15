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

gem 'openssl'
require 'openssl'
require 'base64'
require 'tempfile'

# The RSA key (either private or public).
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A key
  class Key
    def initialize(file: nil, text: nil)
      @body = lambda do
        unless file.nil?
          path = File.expand_path(file)
          raise "Can't find RSA key at #{file} (#{path})" unless File.exist?(path)
          return File.read(path)
        end
        unless text.nil?
          return [
            '-----BEGIN PUBLIC KEY-----',
            text.gsub(/(?<=\G.{64})/, "\n"),
            '-----END PUBLIC KEY-----'
          ].join("\n")
        end
        raise 'Either file or text must be set'
      end
    end

    def to_s
      rsa.to_s.strip
    end

    def to_pub
      to_s.delete("\n").gsub(/-{5}[ A-Z]+-{5}/, '')
    end

    def sign(text)
      Base64.encode64(rsa.sign(OpenSSL::Digest::SHA256.new, text)).delete("\n")
    end

    def verify(signature, text)
      rsa.verify(OpenSSL::Digest::SHA256.new, Base64.decode64(signature), text)
    end

    private

    def rsa
      text = @body.call.strip
      unless text.start_with?('-----BEGIN')
        Tempfile.open do |f|
          File.write(f.path, text)
          text = `ssh-keygen -f #{f.path} -e -m pem`
        end
      end
      begin
        OpenSSL::PKey::RSA.new(text)
      rescue OpenSSL::PKey::RSAError => e
        raise "Can't read RSA key (#{e.message}): #{text}"
      end
    end
  end
end
