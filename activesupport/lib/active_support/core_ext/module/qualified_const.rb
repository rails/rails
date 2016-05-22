require 'active_support/core_ext/string/inflections'

#--
# Allows code reuse in the methods below without polluting Module.
#++

module ActiveSupport
  module QualifiedConstUtils
    def self.raise_if_absolute(path)
      raise NameError.new("wrong constant name #$&") if path =~ /\A::[^:]+/
    end

    def self.names(path)
      path.split('::')
    end
  end
end
