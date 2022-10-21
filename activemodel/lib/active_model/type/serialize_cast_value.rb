# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      module DefaultImplementation
        def serialize_cast_value(value)
          value
        end
      end

      def self.included(klass)
        klass.include DefaultImplementation unless klass.method_defined?(:serialize_cast_value)
      end

      def self.serialize(type, value)
        # Using `type.equal?(type.itself_if_...)` is a performant way to also
        # ensure that `type` is not just a DelegateClass instance (e.g.
        # ActiveRecord::Type::Serialized) unintentionally delegating
        # SerializeCastValue methods.
        if type.equal?((type.itself_if_serialize_cast_value_compatible rescue nil))
          type.serialize_cast_value(value)
        else
          type.serialize(value)
        end
      end

      attr_reader :itself_if_serialize_cast_value_compatible

      def initialize(...)
        super
        @itself_if_serialize_cast_value_compatible = self if serialize_cast_value_compatible?
      end

      def serialize_cast_value_compatible?
        ancestors = self.class.ancestors
        ancestors.index(method(:serialize_cast_value).owner) <= ancestors.index(method(:serialize).owner)
      end
    end
  end
end
