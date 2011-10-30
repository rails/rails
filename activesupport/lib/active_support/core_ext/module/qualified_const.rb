require 'active_support/core_ext/string/inflections'

#--
# Allows code reuse in the methods below without polluting Module.
#++
module QualifiedConstUtils
  def self.raise_if_absolute(path)
    raise NameError, "wrong constant name #$&" if path =~ /\A::[^:]+/
  end

  def self.names(path)
    path.split('::')
  end
end

##
# Extends the API for constants to be able to deal with qualified names. Arguments
# are assumed to be relative to the receiver.
#
#--
# Qualified names are required to be relative because we are extending existing
# methods that expect constant names, ie, relative paths of length 1. For example,
# Object.const_get("::String") raises NameError and so does qualified_const_get.
#++
class Module
  if method(:const_defined?).arity == 1
    def qualified_const_defined?(path)
      QualifiedConstUtils.raise_if_absolute(path)

      QualifiedConstUtils.names(path).inject(self) do |mod, name|
        return unless mod.const_defined?(name)
        mod.const_get(name)
      end
      return true
    end
  else
    def qualified_const_defined?(path, search_parents=true)
      QualifiedConstUtils.raise_if_absolute(path)

      QualifiedConstUtils.names(path).inject(self) do |mod, name|
        return unless mod.const_defined?(name, search_parents)
        mod.const_get(name)
      end
      return true
    end
  end

  def qualified_const_get(path)
    QualifiedConstUtils.raise_if_absolute(path)

    QualifiedConstUtils.names(path).inject(self) do |mod, name|
      mod.const_get(name)
    end
  end

  def qualified_const_set(path, value)
    QualifiedConstUtils.raise_if_absolute(path)

    const_name = path.demodulize
    mod_name = path.deconstantize
    mod = mod_name.empty? ? self : qualified_const_get(mod_name)
    mod.const_set(const_name, value)
  end
end
