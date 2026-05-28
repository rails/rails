# frozen_string_literal: true

require "active_model/type"

require "active_record/type/query_predicate"
require "active_record/type/internal/timezone"
require "active_record/type/adapter_specific_registry"

require "active_record/type/type_map"
require "active_record/type/hash_lookup_type_map"

module ActiveRecord
  module Type
    @registry = AdapterSpecificRegistry.new

    class << self
      attr_accessor :registry # :nodoc:
      delegate :add_modifier, to: :registry

      # Add a new type to the registry, allowing it to be referenced as a
      # symbol by {ActiveRecord::Base.attribute}[rdoc-ref:Attributes::ClassMethods#attribute].
      # If your type is only meant to be used with a specific database adapter, you can
      # do so by passing <tt>adapter: :postgresql</tt>. If your type has the same
      # name as a native type for the current adapter, an exception will be
      # raised unless you specify an +:override+ option. <tt>override: true</tt> will
      # cause your type to be used instead of the native type. <tt>override:
      # false</tt> will cause the native type to be used over yours if one exists.
      def register(type_name, klass = nil, **options, &block)
        registry.register(type_name, klass, **options, &block)
      end

      def lookup(*args, adapter: current_adapter_name, **kwargs) # :nodoc:
        registry.lookup(*args, adapter: adapter, **kwargs)
      end

      def default_value # :nodoc:
        @default_value ||= Value.new
      end

      def adapter_name_from(model) # :nodoc:
        model.connection_db_config.adapter.to_sym
      end

      private
        def current_adapter_name
          adapter_name_from(ActiveRecord::Base)
        end
    end

    class Value < ActiveModel::Type::Value
      include QueryPredicate
    end

    class BigInteger < ActiveModel::Type::BigInteger
      include QueryPredicate
    end

    class Binary < ActiveModel::Type::Binary
      include QueryPredicate
    end

    class Boolean < ActiveModel::Type::Boolean
      include QueryPredicate
    end

    class Decimal < ActiveModel::Type::Decimal
      include QueryPredicate
    end

    class Float < ActiveModel::Type::Float
      include QueryPredicate
    end

    class Integer < ActiveModel::Type::Integer
      include QueryPredicate
    end

    class ImmutableString < ActiveModel::Type::ImmutableString
      include QueryPredicate
    end

    class String < ActiveModel::Type::String
      include QueryPredicate
    end

    require "active_record/type/date"
    require "active_record/type/date_time"
    require "active_record/type/decimal_without_scale"
    require "active_record/type/json"
    require "active_record/type/time"
    require "active_record/type/text"
    require "active_record/type/unsigned_integer"

    require "active_record/type/serialized"

    register(:big_integer, Type::BigInteger, override: false)
    register(:binary, Type::Binary, override: false)
    register(:boolean, Type::Boolean, override: false)
    register(:date, Type::Date, override: false)
    register(:datetime, Type::DateTime, override: false)
    register(:decimal, Type::Decimal, override: false)
    register(:float, Type::Float, override: false)
    register(:integer, Type::Integer, override: false)
    register(:immutable_string, Type::ImmutableString, override: false)
    register(:json, Type::Json, override: false)
    register(:string, Type::String, override: false)
    register(:text, Type::Text, override: false)
    register(:time, Type::Time, override: false)
  end
end
