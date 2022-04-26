# frozen_string_literal: true

module ActiveJob
  # Returns the version of the currently loaded Active Job as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 7
    MINOR = 0
    TINY  = 2
    PRE   = "4"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
