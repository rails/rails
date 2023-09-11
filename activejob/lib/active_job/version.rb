# frozen_string_literal: true

require_relative "gem_version"

module ActiveJob
  # Returns the currently loaded version of Active Job as a +Gem::Version+.
  def self.version
    gem_version
  end
end
