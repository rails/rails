# frozen_string_literal: true

# :markup: markdown
require_relative "gem_version"

module ActiveModel
  # Returns the currently loaded version of \Active \Model as a `Gem::Version`.
  def self.version
    gem_version
  end
end
