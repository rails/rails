require_relative "gem_version"

module ActionSystemTest
  # Returns the version of the currently loaded Action System Test as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
