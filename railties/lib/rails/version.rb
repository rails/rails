# frozen_string_literal: true

require_relative "gem_version"

module Rails
  # Returns the currently loaded version of \Rails as a string.
  def self.version
    VERSION::STRING
  end
end
