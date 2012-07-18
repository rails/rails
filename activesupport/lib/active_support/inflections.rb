require 'active_support/inflector/inflections'

module ActiveSupport
  Inflector.inflections do |inflect|
    inflect.plural(/$/, 's')
    inflect.plural(/s$/i, 's')

    inflect.singular(/s$/i, '')
    inflect.singular(/(ss)$/i, '\1')
  end
end
