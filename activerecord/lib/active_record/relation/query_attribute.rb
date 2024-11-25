# frozen_string_literal: true

require "active_model/attribute"

module ActiveRecord
  class Relation
    class QueryAttribute < ActiveModel::Attribute # :nodoc:
      def initialize(...)
        super

        # The query attribute value may be mutated before we actually "compile" the query.
        # To avoid that if the type uses a serializer we eagerly compute the value for database
        if value_before_type_cast.is_a?(StatementCache::Substitute)
          # we don't need to serialize StatementCache::Substitute
        elsif @type.serialized?
          value_for_database
        elsif @type.mutable? # If the type is simply mutable, we deep_dup it.
          @value_before_type_cast = @value_before_type_cast.deep_dup
        end
      end

      def type_cast(value)
        value
      end

      def value_for_database
        @value_for_database = _value_for_database unless defined?(@value_for_database)
        @value_for_database
      end

      def with_cast_value(value)
        QueryAttribute.new(name, value, type)
      end

      def nil?
        unless value_before_type_cast.is_a?(StatementCache::Substitute)
          value_before_type_cast.nil? ||
            (type.respond_to?(:subtype) || type.respond_to?(:normalizer)) && serializable? && value_for_database.nil?
        end
      end

      def infinite?
        infinity?(value_before_type_cast) || serializable? && infinity?(value_for_database)
      end

      def unboundable?
        unless defined?(@_unboundable)
          serializable? { |value| @_unboundable = value <=> 0 } && @_unboundable = nil
        end
        @_unboundable
      end

      def ==(other)
        super && value_for_database == other.value_for_database
      end
      alias eql? ==

      def hash
        [self.class, name, value_for_database, type].hash
      end

      private
        def infinity?(value)
          value.respond_to?(:infinite?) && value.infinite?
        end
    end
  end
end
