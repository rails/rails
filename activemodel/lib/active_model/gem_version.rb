module ActiveModel
  # Returns the version of the currently loaded ActiveModel as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 4
    MINOR = 1
    TINY  = 14
    PRE   = "2"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
