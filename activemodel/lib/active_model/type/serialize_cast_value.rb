# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      extend ActiveSupport::Concern

      module ClassMethods
        def serialize_cast_value_compatible?
          return @serialize_cast_value_compatible if defined?(@serialize_cast_value_compatible)
          @serialize_cast_value_compatible = ancestors.index(instance_method(:serialize_cast_value).owner) <= ancestors.index(instance_method(:serialize).owner)
        end
      end

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

      def itself_if_serialize_cast_value_compatible
        self if self.class.serialize_cast_value_compatible?
      end

      def initialize(...)
        super
        self.class.serialize_cast_value_compatible? # eagerly compute
      end
    end
  end
end
