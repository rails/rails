# frozen_string_literal: true

module ActionCable
  # Returns the version of the currently loaded Action Cable as a <tt>Gem::Version</tt>.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 7
    MINOR = 0
    TINY  = 0
    PRE   = "alpha"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
