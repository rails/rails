# frozen_string_literal: true

require_relative "gem_version"

module ActionMailer
  # Returns the currently loaded version of Action Mailer as a
  # <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
