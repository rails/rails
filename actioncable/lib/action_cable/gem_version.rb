# frozen_string_literal: true

# :markup: markdown

module ActionCable
  # Returns the currently loaded version of Action Cable as a `Gem::Version`.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 8
    MINOR = 0
    TINY  = 1
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
