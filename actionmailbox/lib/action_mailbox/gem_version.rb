# frozen_string_literal: true

module ActionMailbox
  # Returns the currently-loaded version of Action Mailbox as a <tt>Gem::Version</tt>.
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 6
    MINOR = 1
    TINY  = 5
    PRE   = "1"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
