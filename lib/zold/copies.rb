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

require 'time'
require 'csv'

# The list of copies.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All copies
  class Copies
    def initialize(dir)
      @dir = dir
    end

    def clean
      list = load
      list.reject! { |s| s[:time] < Time.now - 24 }
      save(list)
      Dir.new(@dir).select { |f| f =~ /[0-9]+/ }.each do |f|
        File.delete(File.join(@dir, f)) if list.find { |s| s[:name] == f }.nil?
      end
    end

    def add(content, host, port, score, time = Time.now)
      raise "Content can't be empty" if content.empty?
      raise 'TCP port must be of type Integer' unless port.is_a?(Integer)
      raise "TCP port can't be negative: #{port}" if port < 0
      raise 'Time must be of type Time' unless time.is_a?(Time)
      raise "Time must be in the past: #{time}" if time > Time.now
      raise 'Score must be Integer' unless score.is_a?(Integer)
      raise "Score can't be negative: #{score}" if score < 0
      FileUtils.mkdir_p(@dir)
      list = load
      target = list.find { |s| File.read(File.join(@dir, s[:name])) == content }
      if target.nil?
        max = Dir.new(@dir)
          .select { |f| f =~ /[0-9]+/ }
          .map(&:to_i)
          .max
        max = 0 if max.nil?
        name = (max + 1).to_s
        File.write(File.join(@dir, name), content)
      else
        name = target[:name]
      end
      list.reject! { |s| s[:host] == host && s[:port] == port }
      list << {
        name: name,
        host: host,
        port: port,
        score: score,
        time: time
      }
      save(list)
    end

    def all
      load.group_by { |s| s[:name] }.map do |name, scores|
        {
          name: name,
          path: File.join(@dir, name),
          score: scores.select { |s| s[:time] > Time.now - 24 }
            .map { |s| s[:score] }
            .inject(&:+)
        }
      end
    end

    private

    def load
      FileUtils.mkdir_p(File.dirname(file))
      FileUtils.touch(file)
      CSV.read(file).map do |s|
        {
          name: s[0],
          host: s[1],
          port: s[2].to_i,
          score: s[3].to_i,
          time: Time.parse(s[4])
        }
      end
    end

    def save(list)
      File.write(
        file,
        list.map do |r|
          [
            r[:name], r[:host],
            r[:port], r[:score],
            r[:time].utc.iso8601
          ].join(',')
        end.join("\n")
      )
    end

    def file
      File.join(@dir, 'scores')
    end
  end
end
