# from facets (http://facets.rubyforge.org)
require 'i18n/core_ext/hash/slice'

class Hash
  def except(*less_keys)
    slice(*keys - less_keys)
  end
end unless Hash.method_defined?(:except)