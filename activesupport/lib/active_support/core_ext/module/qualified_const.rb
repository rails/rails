require "active_support/core_ext/string/inflections"

#--
# Allows code reuse in the methods below without polluting Module.
#++

module ActiveSupport
  module QualifiedConstUtils
    def self.raise_if_absolute(path)
      raise NameError.new("wrong constant name #$&") if path =~ /\A::[^:]+/
    end

    def self.names(path)
      path.split("::")
    end
  end
end

##
# Extends the API for constants to be able to deal with qualified names. Arguments
# are assumed to be relative to the receiver.
#
#--
# Qualified names are required to be relative because we are extending existing
# methods that expect constant names, ie, relative paths of length 1. For example,
# Object.const_get('::String') raises NameError and so does qualified_const_get.
#++
class Module
  def qualified_const_defined?(path, search_parents = true)
    ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
      Module#qualified_const_defined? is deprecated in favour of the builtin
      Module#const_defined? and will be removed in Rails 5.1.
    MESSAGE

    ActiveSupport::QualifiedConstUtils.raise_if_absolute(path)

    ActiveSupport::QualifiedConstUtils.names(path).inject(self) do |mod, name|
      return unless mod.const_defined?(name, search_parents)
      mod.const_get(name)
    end
    return true
  end

  def qualified_const_get(path)
    ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
      Module#qualified_const_get is deprecated in favour of the builtin
      Module#const_get and will be removed in Rails 5.1.
    MESSAGE

    ActiveSupport::QualifiedConstUtils.raise_if_absolute(path)

    ActiveSupport::QualifiedConstUtils.names(path).inject(self) do |mod, name|
      mod.const_get(name)
    end
  end

  def qualified_const_set(path, value)
    ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
      Module#qualified_const_set is deprecated in favour of the builtin
      Module#const_set and will be removed in Rails 5.1.
    MESSAGE

    ActiveSupport::QualifiedConstUtils.raise_if_absolute(path)

    const_name = path.demodulize
    mod_name = path.deconstantize
    mod = mod_name.empty? ? self : const_get(mod_name)
    mod.const_set(const_name, value)
  end
end
