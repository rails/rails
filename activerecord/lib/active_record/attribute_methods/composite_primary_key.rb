# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module CompositePrimaryKey # :nodoc:
      # Returns the primary key column's value. If the primary key is composite,
      # returns an array of the primary key column values.
      def id
        if primary_key_is_composite?
          @primary_key.map { |pk| _read_attribute(pk) }
        else
          super
        end
      end

      def primary_key_values_present? # :nodoc:
        if primary_key_is_composite?
          id.all?
        else
          super
        end
      end

      # Sets the primary key column's value. If the primary key is composite,
      # raises TypeError when the set value not enumerable.
      def id=(value)
        if primary_key_is_composite?
          raise TypeError, "Expected value matching #{@primary_key.inspect}, got #{value.inspect}." unless value.is_a?(Enumerable)
          @primary_key.zip(value) { |attr, value| _write_attribute(attr, value) }
        else
          super
        end
      end

      # Queries the primary key column's value. If the primary key is composite,
      # all primary key column values must be queryable.
      def id?
        if primary_key_is_composite?
          @primary_key.all? { |col| _query_attribute(col) }
        else
          super
        end
      end

      # Returns the primary key column's value before type cast. If the primary key is composite,
      # returns an array of primary key column values before type cast.
      def id_before_type_cast
        if primary_key_is_composite?
          @primary_key.map { |col| attribute_before_type_cast(col) }
        else
          super
        end
      end

      # Returns the primary key column's previous value. If the primary key is composite,
      # returns an array of primary key column previous values.
      def id_was
        if primary_key_is_composite?
          @primary_key.map { |col| attribute_was(col) }
        else
          super
        end
      end

      # Returns the primary key column's value from the database. If the primary key is composite,
      # returns an array of primary key column values from database.
      def id_in_database
        if primary_key_is_composite?
          @primary_key.map { |col| attribute_in_database(col) }
        else
          super
        end
      end

      def id_for_database # :nodoc:
        if primary_key_is_composite?
          @primary_key.map { |col| @attributes[col].value_for_database }
        else
          super
        end
      end

      private
        def primary_key_is_composite?
          @primary_key.is_a?(Array)
        end
    end
  end
end
