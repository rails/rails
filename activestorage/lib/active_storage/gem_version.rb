# frozen_string_literal: true

module ActiveStorage
  # Returns the version of the currently loaded Active Storage as a <tt>Gem::Version</tt>.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 7
    MINOR = 0
    TINY  = 0
    PRE   = "alpha2"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
