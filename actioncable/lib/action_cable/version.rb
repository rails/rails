require_relative 'gem_version'

module ActionCable
  # Returns the version of the currently loaded Action Cable as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
