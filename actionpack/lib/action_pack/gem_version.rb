# frozen_string_literal: true

# :markup: markdown

module ActionPack
  # Returns the currently loaded version of Action Pack as a `Gem::Version`.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 8
    MINOR = 1
    TINY  = 0
    PRE   = "alpha"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
