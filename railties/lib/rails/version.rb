require_relative "gem_version"

module Rails
  # Returns the version of the currently loaded Rails as a string.
  def self.version
    VERSION::STRING
  end
end
