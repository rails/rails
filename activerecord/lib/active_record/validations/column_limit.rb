# :markup: markdown
# frozen_string_literal: true

require "bigdecimal"

module ActiveRecord
  module Validations
    class ColumnLimitValidator < ActiveModel::EachValidator # :nodoc:
      def validate_each(record, attribute, value)
        column = backing_column(record.class, attribute)
        return if value.nil? || array_column?(column) || bit_column?(column)

        type = record.class.type_for_attribute(column.name)

        case column.type
        when :integer
          validate_integer_limit(record, attribute, type, value, column)
        when :decimal
          validate_decimal_limit(record, attribute, type, value, column)
        when :string
          validate_character_limit(record, attribute, type, value, column)
        when :text, :binary
          validate_byte_limit(record, attribute, type, value, column)
        end
      end

      private
        def backing_column(model, attribute)
          name = model.attribute_aliases[attribute.to_s] || attribute.to_s
          model.columns_hash.fetch(name) do
            raise ArgumentError, "cannot validate the column limit of #{attribute.inspect}, which is not backed by a column"
          end
        end

        def validate_integer_limit(record, attribute, type, value, column)
          return unless column.limit

          number = to_number(integer_value(type, value))
          return if number.nil?

          minimum, maximum = integer_bounds(column.limit, unsigned_column?(column))
          add_range_error(record, attribute, value, number, minimum, maximum)
        end

        # The number the column will store: enum labels map to their integer, and
        # serializable? yields the cast value on overflow so a value wider than
        # the attribute type is still measured against the column bound.
        def integer_value(type, value)
          captured = nil
          if type.serializable?(value) { |cast| captured = cast }
            type.serialize(value)
          else
            captured
          end
        end

        def integer_bounds(byte_limit, unsigned)
          magnitude = 1 << (byte_limit * 8)
          unsigned ? [0, magnitude - 1] : [-(magnitude >> 1), (magnitude >> 1) - 1]
        end

        def validate_decimal_limit(record, attribute, type, value, column)
          return unless column.precision

          number = to_number(type.serialize(value))
          return if number.nil?

          maximum = BigDecimal(10**column.precision - 1) / (10**(column.scale || 0))
          minimum = unsigned_column?(column) ? BigDecimal(0) : -maximum
          add_range_error(record, attribute, value, number, minimum, maximum)
        end

        # serialize may return the database value as a string; coerce it to a
        # number so the range checks compare like with like.
        def to_number(value)
          case value
          when Numeric then value
          when String then BigDecimal(value, exception: false)
          end
        end

        def add_range_error(record, attribute, value, number, minimum, maximum)
          if !number.finite?
            record.errors.add(attribute, :not_a_number, **error_options(value))
          elsif number > maximum
            record.errors.add(attribute, :less_than_or_equal_to, **error_options(value, count: display_bound(maximum)))
          elsif number < minimum
            record.errors.add(attribute, :greater_than_or_equal_to, **error_options(value, count: display_bound(minimum)))
          end
        end

        def validate_character_limit(record, attribute, type, value, column)
          if column.limit && stored_string(type, value).length > column.limit
            record.errors.add(attribute, :too_long, **error_options(value, count: column.limit))
          end
        end

        def validate_byte_limit(record, attribute, type, value, column)
          if column.limit && stored_string(type, value).bytesize > column.limit
            record.errors.add(attribute, :too_large_in_bytes, **error_options(value, count: column.limit))
          end
        end

        def stored_string(type, value)
          type.serialize(value).to_s
        end

        def unsigned_column?(column)
          column.respond_to?(:unsigned?) && column.unsigned?
        end

        def array_column?(column)
          column.respond_to?(:array?) && column.array?
        end

        def bit_column?(column)
          column.sql_type.to_s.downcase.start_with?("bit")
        end

        def display_bound(bound)
          bound.is_a?(BigDecimal) ? bound.to_s("F") : bound
        end

        def error_options(value, **details)
          options.merge(value: value, **details)
        end
    end

    module ClassMethods
      # Validates that the value of the specified attribute fits within the
      # limit its backing database column declares. Depending on the adapter an
      # over-limit value would otherwise raise a +RangeError+, be truncated, or
      # be stored oversized on save.
      #
      #   class Ledger < ActiveRecord::Base
      #     validates_column_limit_of :account_id
      #   end
      #
      # The value is checked as the column stores it, so enum, serialized, and
      # encrypted attributes are checked against their serialized form rather
      # than their public value.
      #
      # The bound depends on the column type:
      #
      # * Integer columns must hold a value inside the range their byte size and
      #   signedness allow.
      # * Decimal columns must hold a value within the magnitude their precision
      #   and scale allow.
      # * String columns must not exceed the column's character limit.
      # * Text and binary columns must not exceed the column's byte limit.
      #
      # The check depends on the adapter reporting a limit (or precision) for
      # the column. When it reports none the validation is skipped, so the set
      # of covered columns varies by adapter. An integer column whose adapter
      # reports no limit is left to the integer type's own range check on save.
      # MySQL +bit+ columns are skipped because their limit counts bits, and
      # array columns because the validator does not recurse into their
      # elements.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default depends on the
      #   violated bound).
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See ActiveModel::Validations::ClassMethods#validates for more information.
      def validates_column_limit_of(*attr_names)
        validates_with ColumnLimitValidator, _merge_attributes(attr_names)
      end
    end
  end
end
