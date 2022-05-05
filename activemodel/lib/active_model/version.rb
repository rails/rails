# frozen_string_literal: true

require_relative "gem_version"

module ActiveModel
  # Returns the currently loaded version of \Active \Model as a <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
