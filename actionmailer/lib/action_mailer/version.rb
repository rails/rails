require_relative 'gem_version'

module ActionMailer
  # Returns the version of the currently loaded Action Mailer as a
  # <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
