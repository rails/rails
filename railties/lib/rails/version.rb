module Rails
  # Returns the version of the currently loaded Rails as a Gem::Version
  def self.version
    Gem::Version.new "4.0.0.beta1"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = Rails.version.segments
    STRING = Rails.version.to_s
  end
end
