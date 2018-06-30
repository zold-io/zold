require 'semantic'

module Zold
  # Class to manage data upgrades (when zold itself upgrades).
  class VersionUpgradeManager
    # @todo #285:30min Refactor so we don't just assume there's .zoldata
    #  in the current directory. Possibly something like a config object
    #  should be introduced.
    #
    # @todo #285:30min Communicate the ongoing upgrade and its steps to the user.
    #  The user should know:
    #  - If the upgrade is happening.
    #  - What upgrade scripts are run.
    #  - On failure there should be a report of what failed.
    #
    # @todo #285:30min Write the upgrade manager tests that ensure:
    #  - Nothing breaks without the version file.
    #  - The upgrade scripts run when there is a version file and there are pending upgrade scripts.
    #  - Make sure *only* the correct upgrade scripts run.
    def self.run
      from_version = data_version
      return unless from_version

      upgrade(from_version)
      File.open('.zoldata/version', 'w') do |file|
        file.puts(Zold::VERSION)
      end
    end

    def self.data_version
      version_string = File.read('.zoldata/version')
      Semantic::Version.new(version_string)
    rescue Errno::ENOENT
      # @todo #285:30min Save the version if there is no .zoldata/version
      #  present yet. This is breaking the specs, it needs some additional time.

      # File.open('.zoldata/version', 'w') do |file|
      #   file.puts(Zold::VERSION)
      # end

      false
    end

    # @todo #285:30min Compare from_version with the current version and run all the scripts
    #  from the upgrades directory that are in between these two versions.
    def self.upgrade(from_version); end
  end
end
