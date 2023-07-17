# frozen_string_literal: true

require_relative "gem_version"

module ActionPack
  # Returns the currently loaded version of Action Pack as a +Gem::Version+.
  def self.version
    gem_version
  end
end
