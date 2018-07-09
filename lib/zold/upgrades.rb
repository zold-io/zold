require_relative 'log'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory, log: Log::Verbose.new)
      @version = version
      @directory = directory
      @log = log
    end

    def run
      scripts.each do |script|
        @version.apply(script)
      end
    end

    private

    def scripts
      Dir.glob("#{@directory}/*.rb").sort.map do |path|
        basename = File.basename(path)
        match = basename.match(/^(\d+\.\d+\.\d+)\.rb$/)
        raise 'An upgrade script has to be named <version>.rb.' unless match
        match[1]
      end
    end
  end
end
