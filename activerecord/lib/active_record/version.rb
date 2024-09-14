# frozen_string_literal: true

require_relative "gem_version"

module ActiveRecord
  # Returns the currently loaded version of Active Record as a +Gem::Version+.
  def self.version
    gem_version
  end
end
