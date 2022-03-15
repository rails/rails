# frozen_string_literal: true

require_relative "gem_version"

module ActiveJob
  # Returns the currently loaded version of Active Job as a <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
