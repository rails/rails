module Gem
  class Version
    # Checks if this version is inferior than the other.
    #
    #   Gem::Version.new("1.8.7") < "1.9.2" #=> true
    #   Gem::Version.new("1.9") < "1.8.7"   #=> false
    #
    # <tt>Gem.ruby_version < "1.9.2"</tt> can be handy, as <tt>Gem.ruby_version</tt> returns
    # an object of <tt>Gem::Version</tt>
    def < other_version
      (self <=> Version.new(other_version)) == -1
    end

    # Checks if this version is superior than the other.
    #
    #   Gem::Version.new("1.8.7") > "1.9.2" #=> false
    #   Gem::Version.new("1.9") > "1.8.7"   #=> true
    #
    # <tt>Gem.ruby_version > "1.9.2"</tt> can be handy, as <tt>Gem.ruby_version</tt> returns
    # an object of <tt>Gem::Version</tt>
    def > other_version
      (self <=> Version.new(other_version)) == 1
    end

    # Checks if both the versions are similar.
    #
    #   Gem::Version.new("1.9.2") == "1.9.2" #=> true
    #   Gem::Version.new("1.9") == "1.8.7"   #=> false
    #
    # <tt>Gem.ruby_version == "1.9.2"</tt> can be handy, as <tt>Gem.ruby_version</tt> returns
    # an object of <tt>Gem::Version</tt>
    def == other_version
      (self <=> Version.new(other_version)) == 0
    end

    # Checks if this version is superior or similar to the other.
    #
    #   Gem::Version.new("1.8.7") >= "1.9.2" #=> false
    #   Gem::Version.new("1.9") >= "1.8.7"   #=> true
    #   Gem::Version.new("1.9") >= "1.9"     #=> true
    #
    # <tt>Gem.ruby_version >= "1.9.2"</tt> can be handy, as <tt>Gem.ruby_version</tt> returns
    # an object of <tt>Gem::Version</tt>
    def >= other_version
      (self > other_version) || (self == other_version)
    end

    # Checks if this version is inferior or similar to the other.
    #
    #   Gem::Version.new("1.8.7") <= "1.9.2"  #=> true
    #   Gem::Version.new("1.8.7") <= "1.8.7"  #=> true
    #   Gem::Version.new("1.9") <= "1.8.7"    #=> false
    #
    # <tt>Gem.ruby_version <= "1.9.2"</tt> can be handy, as <tt>Gem.ruby_version</tt> returns
    # an object of <tt>Gem::Version</tt>
    def <= other_version
      (self < other_version) || (self == other_version)
    end
  end
end

