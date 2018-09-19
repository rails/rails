# frozen_string_literal: true

module ActiveRecord
  # Returns the version of the currently loaded Active Record as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 6
    MINOR = 0
    TINY  = 0
    PRE   = "alpha"

    STRING = [[MAJOR, MINOR, TINY].join("."), PRE].compact.join("-")
  end
end
