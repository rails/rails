module ActionView
  # Returns the version of the currently loaded ActionView as a Gem::Version
  def self.version
    Gem::Version.new "4.1.0.beta"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = ActionView.version.segments
    STRING = ActionView.version.to_s
  end
end
