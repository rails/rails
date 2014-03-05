require_relative 'gem_version'

module ActiveModel
  # Returns the version of the currently loaded ActiveModel as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
