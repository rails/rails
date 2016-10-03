require "active_model/type/helpers"
require "active_model/type/value"

require "active_model/type/big_integer"
require "active_model/type/binary"
require "active_model/type/boolean"
require "active_model/type/date"
require "active_model/type/date_time"
require "active_model/type/decimal"
require "active_model/type/float"
require "active_model/type/immutable_string"
require "active_model/type/integer"
require "active_model/type/string"
require "active_model/type/time"

require "active_model/type/registry"

module ActiveModel
  module Type
    @registry = Registry.new

    class << self
      attr_accessor :registry # :nodoc:
      delegate :add_modifier, to: :registry

      # Add a new type to the registry, allowing it to be referenced as a
      # symbol by ActiveModel::Attributes::ClassMethods#attribute.  If your
      # type is only meant to be used with a specific database adapter, you can
      # do so by passing +adapter: :postgresql+. If your type has the same
      # name as a native type for the current adapter, an exception will be
      # raised unless you specify an +:override+ option. +override: true+ will
      # cause your type to be used instead of the native type. +override:
      # false+ will cause the native type to be used over yours if one exists.
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
