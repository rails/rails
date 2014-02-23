module ActionView
  # Returns the version of the currently loaded ActionView as a Gem::Version
  def self.version
    Gem::Version.new "4.2.0.alpha"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = ActionView.version.segments
    STRING = ActionView.version.to_s
  end
end
