require_relative 'log'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory, log: Log::Verbose.new)
      @version = version
      @directory = directory
      @log = log
    end

    # @todo #285:30min Write the upgrade manager tests that ensure:
    #  - Nothing breaks without the version file.
    #  - The upgrade scripts run when there is a version file and there are pending upgrade scripts.
    #  - Make sure *only* the correct upgrade scripts run.
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
