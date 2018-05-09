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

# The list of remotes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All remotes
  class Remotes
    def initialize(file)
      @file = file
    end

    def total
      load.length
    end

    def all
      load
    end

    def add(address, port = '80')
      list = load
      list << { address: address, port: port, score: 0 }
      list.uniq! { |r| r[:address] }
      save(list)
    end

    def remove(address)
      list = load
      list.reject! { |r| r[:address] == address }
      save(list)
    end

    def score(address)
      load.find { |r| r[:address] == address }[:score]
    end

    def rescore(address, score)
      list = load
      list.find { |r| r[:address] == address }[:score] = score
      save(list)
    end

    private

    def load
      unless File.exist?(@file)
        FileUtils.copy(
          File.join(File.dirname(__FILE__), '../../resources/remotes'),
          @file
        )
      end
      CSV.read(@file).map do |r|
        { address: r[0], port: r[1].to_i, score: r[2].to_i }
      end
    end

    def save(list)
      File.write(
        @file,
        list.map { |r| "#{r[:address]},#{r[:port]},#{r[:score]}" }.join("\n")
      )
    end
  end
end
