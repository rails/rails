# frozen_string_literal: true

module ActiveRecord
  module Type
    # A JSON type that wraps deserialized values in HashWithIndifferentAccess.
    #
    # Used by ActiveRecord::Store when the underlying column is a native json
    # or jsonb type, so that +store+ provides the same indifferent access as
    # it does on text columns (via IndifferentCoder / Type::Serialized) without
    # the double-serialization bug that occurs when Type::Serialized wraps a
    # json/jsonb column.
    class IndifferentJson < Json
      def deserialize(value)
        result = super
        if result.is_a?(Hash)
          result.with_indifferent_access
        else
          result
        end
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end
    end
  end
end
