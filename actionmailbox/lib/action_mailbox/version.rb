# frozen_string_literal: true

require_relative "gem_version"

module ActionMailbox
  # Returns the currently-loaded version of Action Mailbox as a <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
