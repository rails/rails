# frozen_string_literal: true

require 'active_model/attribute'

module ActiveRecord
  class Relation
    class QueryAttribute < ActiveModel::Attribute # :nodoc:
      def type_cast(value)
        value
      end

      def value_for_database
        @value_for_database ||= super
      end

      def with_cast_value(value)
        QueryAttribute.new(name, value, type)
      end

      def nil?
        unless value_before_type_cast.is_a?(StatementCache::Substitute)
          value_before_type_cast.nil? ||
            type.respond_to?(:subtype, true) && value_for_database.nil?
        end
      rescue ::RangeError
      end

      def infinite?
        infinity?(value_before_type_cast) || infinity?(value_for_database)
      rescue ::RangeError
      end

      def unboundable?
        if defined?(@_unboundable)
          @_unboundable
        else
          value_for_database unless value_before_type_cast.is_a?(StatementCache::Substitute)
          @_unboundable = nil
        end
      rescue ::RangeError
        @_unboundable = type.cast(value_before_type_cast) <=> 0
      end

      private
        def infinity?(value)
          value.respond_to?(:infinite?) && value.infinite?
        end
    end
  end
end
