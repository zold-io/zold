# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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
require 'openssl'
require 'csv'
require 'futex'
require 'backtrace'
require_relative 'log'
require_relative 'size'
require_relative 'wallet'
require_relative 'dir_items'

# The list of copies.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All copies
  class Copies
    # Extension for copy files
    EXT = '.zc'

    def initialize(dir, log: Log::NULL)
      @dir = dir
      @log = log
    end

    def root
      File.expand_path(File.join(@dir, '..'))
    end

    def to_s
      File.basename(@dir)
    end

    # Delete all copies that are older than the "max" age provided, in seconds.
    def clean(max: 24 * 60 * 60)
      Futex.new(file, log: @log).open do
        list = load
        list.reject! do |s|
          if s[:time] >= Time.now - max
            false
          else
            @log.debug("Copy ##{s[:name]}/#{s[:host]}:#{s[:port]} is too old, over #{Age.new(s[:time])}")
            true
          end
        end
        save(list)
        deleted = 0
        files.each do |f|
          next unless list.find { |s| s[:name] == File.basename(f, Copies::EXT) }.nil?
          file = File.join(@dir, f)
          size = File.size(file)
          File.delete(file)
          @log.debug("Copy at #{f} deleted: #{Size.new(size)}")
          deleted += 1
        end
        list.select! do |s|
          cp = File.join(@dir, "#{s[:name]}#{Copies::EXT}")
          wallet = Wallet.new(cp)
          begin
            wallet.refurbish
            raise "Invalid protocol #{wallet.protocol} in #{cp}" unless wallet.protocol == Zold::PROTOCOL
            true
          rescue StandardError => e
            FileUtils.rm_rf(cp)
            @log.debug("Copy at #{cp} deleted: #{Backtrace.new(e)}")
            deleted += 1
            false
          end
        end
        save(list)
        deleted
      end
    end

    def remove(host, port)
      Futex.new(file, log: @log).open do
        save(load.reject { |s| s[:host] == host && s[:port] == port })
      end
    end

    # Returns the name of the copy
    def add(content, host, port, score, time: Time.now, master: false)
      raise "Content can't be empty" if content.empty?
      raise 'TCP port must be of type Integer' unless port.is_a?(Integer)
      raise "TCP port can't be negative: #{port}" if port.negative?
      raise 'Time must be of type Time' unless time.is_a?(Time)
      raise "Time must be in the past: #{time}" if time > Time.now
      raise 'Score must be Integer' unless score.is_a?(Integer)
      raise "Score can't be negative: #{score}" if score.negative?
      FileUtils.mkdir_p(@dir)
      Futex.new(file, log: @log).open do
        list = load
        target = list.find do |s|
          f = File.join(@dir, "#{s[:name]}#{Copies::EXT}")
          digest = OpenSSL::Digest::SHA256.new(content).hexdigest
          File.exist?(f) && OpenSSL::Digest::SHA256.file(f).hexdigest == digest
        end
        if target.nil?
          max = DirItems.new(@dir).fetch
            .select { |f| File.basename(f, Copies::EXT) =~ /^[0-9]+$/ }
            .map(&:to_i)
            .max
          max = 0 if max.nil?
          name = (max + 1).to_s
          IO.write(File.join(@dir, "#{name}#{Copies::EXT}"), content)
        else
          name = target[:name]
        end
        list.reject! { |s| s[:host] == host && s[:port] == port }
        list << {
          name: name,
          host: host,
          port: port,
          score: score,
          time: time,
          master: master
        }
        save(list)
        name
      end
    end

    def all
      Futex.new(file, log: @log).open(false) do
        load.group_by { |s| s[:name] }.map do |name, scores|
          {
            name: name,
            path: File.join(@dir, "#{name}#{Copies::EXT}"),
            total: scores.count,
            master: scores.any? { |s| s[:master] },
            score: scores.select { |s| s[:time] > Time.now - 24 * 60 * 60 }
              .map { |s| s[:score] }
              .inject(&:+) || 0
          }
        end.select { |c| File.exist?(c[:path]) }.sort_by { |c| [c[:master] ? 1 : 0, c[:score].to_s] }.reverse
      end
    end

    def load
      FileUtils.mkdir_p(File.dirname(file))
      FileUtils.touch(file)
      CSV.read(file).select { |s| s.count == 6 }.map do |s|
        {
          name: s[0],
          host: s[1],
          port: s[2].to_i,
          score: s[3].to_i,
          time: Txn.parse_time(s[4]),
          master: s[5] == 'M'
        }
      end
    end

    private

    def save(list)
      IO.write(
        file,
        list.map do |r|
          [
            r[:name],
            r[:host],
            r[:port],
            r[:score],
            r[:time].utc.iso8601,
            r[:master] ? 'M' : 'E'
          ].join(',')
        end.join("\n")
      )
    end

    def files
      DirItems.new(@dir).fetch.select { |f| File.basename(f, Copies::EXT) =~ /^[0-9]+$/ }
    end

    def file
      File.join(@dir, "scores#{Copies::EXT}")
    end
  end
end
