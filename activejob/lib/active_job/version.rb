require_relative 'gem_version'

module ActiveJob
  # Returns the version of the currently loaded ActiveJob as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
