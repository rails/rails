# frozen_string_literal: true

module ActionMailer
  # Returns the version of the currently loaded Action Mailer as a <tt>Gem::Version</tt>.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 5
    MINOR = 2
    TINY  = 0
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
