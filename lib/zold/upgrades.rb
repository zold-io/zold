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
  # By comparing Zold::VERSION with the data version we determine
  # which upgrade scripts will be executed.
  #
  # If the data version is the same as Zold::VERSION, the data is
  # up to date.
  #
  # If the data version is lower than Zold::VERSION, we will look into
  # the `upgrades/` directory and any scripts from the data version
  # up will be executed.
  #
  # The version of an upgrade script is extracted from the name
  # which is formatted as`<version>.rb`, so for instance `upgrades/0.0.1.rb` etc.
  #
  # If there is no version file, as it would if the data were created
  # by a version of Zold that doesn't have this class implemented yet,
  # all the upgrade scripts have to run.
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
