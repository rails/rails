# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      def self.included(klass)
        unless klass.respond_to?(:included_serialize_cast_value)
          klass.singleton_class.attr_accessor :included_serialize_cast_value
          klass.silence_redefinition_of_method(:itself_if_class_included_serialize_cast_value)
          klass.attr_reader :itself_if_class_included_serialize_cast_value
        end
        klass.included_serialize_cast_value = true
      end

      def self.serialize(type, value)
        # Verify that `type.class` explicitly included SerializeCastValue.
        # Using `type.equal?(type.itself_if_...)` is a performant way to also
        # ensure that `type` is not just a DelegateClass instance (e.g.
        # ActiveRecord::Type::Serialized) unintentionally delegating
        # SerializeCastValue methods.
        if type.equal?((type.itself_if_class_included_serialize_cast_value rescue nil))
          type.serialize_cast_value(value)
        else
          type.serialize(value)
        end
      end

      def initialize(...)
        @itself_if_class_included_serialize_cast_value = self if self.class.included_serialize_cast_value
        super
      end

      def serialize_cast_value(value)
        value
      end
    end
  end
end
