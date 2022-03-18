# frozen_string_literal: true

require_relative "gem_version"

module ActionView
  # Returns the currently loaded version of Action View as a <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
