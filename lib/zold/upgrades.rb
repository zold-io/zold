require 'semantic'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class Upgrades
    def initialize(version_file)
      @version_file = version_file
    end

    # @todo #285:30min Write the upgrade manager tests that ensure:
    #  - Nothing breaks without the version file.
    #  - The upgrade scripts run when there is a version file and there are pending upgrade scripts.
    #  - Make sure *only* the correct upgrade scripts run.
    def run
      from_version = @version_file.version
      return unless from_version
      upgrade(from_version)
      @version_file.save(Zold::VERSION)
    end

    private

    # @todo #285:30min Compare from_version with the current version and run all the scripts
    #  from the upgrades directory that are in between these two versions.
    def upgrade(from_version); end
  end
end
