module ActiveSupport
  # Returns the version of the currently loaded ActiveSupport as a Gem::Version
  def self.version
    Gem::Version.new "4.0.3"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = ActiveSupport.version.segments
    STRING = ActiveSupport.version.to_s
  end
end
