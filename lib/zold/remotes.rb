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

require 'csv'
require 'uri'
require 'fileutils'

# The list of remotes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All remotes
  class Remotes
    PORT = 4096

    def initialize(file)
      @file = file
    end

    def total
      load.length
    end

    def all
      load.sort_by { |r| r[:score] }.reverse
    end

    def clean
      save([])
    end

    def reset
      FileUtils.mkdir_p(File.dirname(@file))
      FileUtils.copy(
        File.join(File.dirname(__FILE__), '../../resources/remotes'),
        @file
      )
    end

    def exists?(host, port = Remotes::PORT)
      !load.find { |r| r[:host] == host && r[:port] == port }.nil?
    end

    def add(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Port can\'t be negative' if port < 0
      raise 'Port can\'t be over 65536' if port > 0xffff
      list = load
      list << { host: host, port: port, score: 0 }
      list.uniq! { |r| "#{r[:host]}:#{r[:port]}" }
      save(list)
    end

    def remove(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      list = load
      list.reject! { |r| r[:host] == host && r[:port] == port }
      save(list)
    end

    def score(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      load.find { |r| r[:host] == host && r[:port] == port }[:score]
    end

    def rescore(host, port, score)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      list = load
      list.find do |r|
        r[:host] == host && r[:port] == port
      end[:score] = score
      save(list)
    end

    private

    def load
      CSV.read(file).map do |r|
        {
          host: r[0],
          port: r[1].to_i,
          score: r[2].to_i,
          home: URI("http://#{r[0]}:#{r[1]}/")
        }
      end
    end

    def save(list)
      File.write(
        file,
        list.map { |r| "#{r[:host]},#{r[:port]},#{r[:score]}" }.join("\n")
      )
    end

    def file
      reset unless File.exist?(@file)
      @file
    end
  end
end
