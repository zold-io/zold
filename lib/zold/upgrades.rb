require 'semantic'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version, directory)
      @version = version
      @directory = directory
    end

    # @todo #285:30min Write the upgrade manager tests that ensure:
    #  - Nothing breaks without the version file.
    #  - The upgrade scripts run when there is a version file and there are pending upgrade scripts.
    #  - Make sure *only* the correct upgrade scripts run.
    def run
      scripts.each do |script|
        @version.apply(parse_version_from_script(script)) do
          run_script(script)
        end
      end
    end

    private

    def scripts
      Dir.glob("#{@directory}/*.rb").sort
    end

    # @todo #285:30min Write path of the script to the logger, execute
    #  it and write its STDERR/STDOUT to the logger. Throw an exception
    #  if the exit value was not 0.
    def run_script(script); end

    def parse_version_from_script(script)
      basename = File.basename(script)
      match = basename.match(/^(\d+\.\d+\.\d+)\.rb$/)
      raise 'An upgrade script has to be named <version>.rb.' unless match
      match[1]
    end
  end
end
