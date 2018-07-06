require_relative 'log'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  #
  # This class will write the version file to the zoldata directory.
  # The version file is a text file containing nothing but the version
  # of the data and a newline. It is named `version`, no extension.
  #
  # If the data is up-to-date, the version of the data is equal to
  # Zold::VERSION.
  #
  # If the version is lower than Zold::VERSION, upgrade scripts from
  # `upgrades/` have to run. They are named `<version>.rb`, so for
  # instance `upgrades/0.0.1.rb` etc.
  #
  # Only the scripts from the data version up need to run.
  #
  # The upgrade scripts are loaded into the running Ruby interpreter
  # rather than being executed.
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
