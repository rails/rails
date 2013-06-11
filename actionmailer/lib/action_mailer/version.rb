module ActionMailer
  # Returns the version of the currently loaded ActionMailer as a Gem::Version
  def self.version
    Gem::Version.new "4.0.0.rc2"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = ActionMailer.version.segments
    STRING = ActionMailer.version.to_s
  end
end
