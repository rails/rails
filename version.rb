module Rails
  def self.version
    Gem::Version.new "4.0.0.beta1"
  end

  module VERSION #:nodoc:
    MAJOR, MINOR, TINY, PRE = Rails.version.segments
    STRING = Rails.version.to_s
  end
end
