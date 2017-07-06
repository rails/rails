require_relative "type/helpers"
require_relative "type/value"

require_relative "type/big_integer"
require_relative "type/binary"
require_relative "type/boolean"
require_relative "type/date"
require_relative "type/date_time"
require_relative "type/decimal"
require_relative "type/float"
require_relative "type/immutable_string"
require_relative "type/integer"
require_relative "type/string"
require_relative "type/time"

require_relative "type/registry"

module ActiveModel
  module Type
    @registry = Registry.new

    class << self
      attr_accessor :registry # :nodoc:

      # Add a new type to the registry, allowing it to be get through ActiveModel::Type#lookup
      def register(type_name, klass = nil, **options, &block)
        registry.register(type_name, klass, **options, &block)
      end

      def lookup(*args, **kwargs) # :nodoc:
        registry.lookup(*args, **kwargs)
      end
    end

    register(:big_integer, Type::BigInteger)
    register(:binary, Type::Binary)
    register(:boolean, Type::Boolean)
    register(:date, Type::Date)
    register(:datetime, Type::DateTime)
    register(:decimal, Type::Decimal)
    register(:float, Type::Float)
    register(:immutable_string, Type::ImmutableString)
    register(:integer, Type::Integer)
    register(:string, Type::String)
    register(:time, Type::Time)
  end
end
