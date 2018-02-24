# frozen_string_literal: true

require "active_model/attribute"

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
        !value_before_type_cast.is_a?(StatementCache::Substitute) &&
          (value_before_type_cast.nil? || value_for_database.nil?)
      end

      def boundable?
        return @_boundable if defined?(@_boundable)
        nil?
        @_boundable = true
      rescue ::RangeError
        @_boundable = false
      end

      def infinity?
        _infinity?(value_before_type_cast) || boundable? && _infinity?(value_for_database)
      end

      private
        def _infinity?(value)
          value.respond_to?(:infinite?) && value.infinite?
        end
    end
  end
end
