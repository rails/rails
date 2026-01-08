# frozen_string_literal: true

module ActiveModel
  # Returns the currently loaded version of \Active \Model as a +Gem::Version+.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 8
    MINOR = 1
    TINY  = 2
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
