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
        unless value_before_type_cast.is_a?(StatementCache::Substitute)
          return true if value_before_type_cast.nil?
          return false unless type.respond_to?(:subtype, true)

          if serializable?
            value_for_database.nil?
          else
            false
          end
        end
      end

      def infinite?
        return true if infinity?(value_before_type_cast)

        if serializable?
          infinity?(value_for_database)
        else
          false
        end
      end

      def unboundable?
        if defined?(@_unboundable)
          @_unboundable
        else
          if value_before_type_cast.is_a?(StatementCache::Substitute)
            @_unboundable = nil
          else
            if type.serializable?(value_before_type_cast)
              @_unboundable = nil
            else
              @_unboundable = type.cast(value_before_type_cast) <=> 0
            end
          end
        end
      end

      private
        def infinity?(value)
          value.respond_to?(:infinite?) && value.infinite?
        end
    end
  end
end
