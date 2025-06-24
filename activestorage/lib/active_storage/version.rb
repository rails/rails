# frozen_string_literal: true

require_relative "gem_version"

module ActiveStorage
  # Returns the currently loaded version of Active Storage as a +Gem::Version+.
  def self.version
    gem_version
  end
end
