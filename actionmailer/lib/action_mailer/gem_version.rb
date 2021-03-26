# frozen_string_literal: true

module ActionMailer
  # Returns the version of the currently loaded Action Mailer as a <tt>Gem::Version</tt>.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 6
    MINOR = 0
    TINY  = 3
    PRE   = "6"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
