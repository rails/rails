# frozen_string_literal: true

# :markup: markdown

require_relative "gem_version"

module ActionText
  # Returns the currently loaded version of Action Text as a `Gem::Version`.
  def self.version
    gem_version
  end
end
