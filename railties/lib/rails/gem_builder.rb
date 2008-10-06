require 'rubygems'
require 'rubygems/installer'

module Rails
  
  # this class hijacks the functionality of Gem::Installer by overloading its 
  # initializer to only provide the information needed by 
  # Gem::Installer#build_extensions (which happens to be what we have)
  class GemBuilder < Gem::Installer

    def initialize(spec, gem_dir)
      @spec    = spec
      @gem_dir = gem_dir
    end

    # silence the underlying builder
    def say(message)
    end

  end
end
