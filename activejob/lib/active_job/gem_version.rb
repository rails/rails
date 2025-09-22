# frozen_string_literal: true

module ActiveJob
  # Returns the currently loaded version of Active Job as a +Gem::Version+.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 8
    MINOR = 0
    TINY  = 3
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
