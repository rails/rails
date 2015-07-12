require_relative 'gem_version'

module ActionPack
  # Returns the version of the currently loaded ActionPack as a Gem::Version
  def self.version
    gem_version
  end
end
