require_relative "gem_version"

module ActionView
  # Returns the version of the currently loaded ActionView as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
