require 'test/unit'
require 'test/unit/assertions'
# active_record is assumed to be loaded by this point

module Test #:nodoc:
  module Unit #:nodoc:
    module Assertions
      # Assert the template object with the given name is an Active Record descendant and is valid.
      def assert_valid_record(key = nil, message = nil)
        record = find_record_in_template(key)
        msg = build_message(message, "Active Record is invalid <?>)", record.errors.full_messages)
        assert_block(msg) { record.valid? }
      end

      # Assert the template object with the given name is an Active Record descendant and is invalid.
      def assert_invalid_record(key = nil, message = nil)
        record = find_record_in_template(key)
        msg = build_message(message, "Active Record is valid)")
        assert_block(msg) { !record.valid? }
      end

      # Assert the template object with the given name is an Active Record descendant and the specified column(s) are valid.
      def assert_valid_column_on_record(key = nil, columns = "", message = nil)
        record = find_record_in_template(key)
        record.send(:validate)

        cols = glue_columns(columns)
        cols.delete_if { |col| !record.errors.invalid?(col) }
        msg = build_message(message, "Active Record has invalid columns <?>)", cols.join(",") )
        assert_block(msg) { cols.empty? }
      end

      # Assert the template object with the given name is an Active Record descendant and the specified column(s) are invalid.
      def assert_invalid_column_on_record(key = nil, columns = "", message = nil)
        record = find_record_in_template(key)
        record.send(:validate)

        cols = glue_columns(columns)
        cols.delete_if { |col| record.errors.invalid?(col) }
        msg = build_message(message, "Active Record has valid columns <?>)", cols.join(",") )
        assert_block(msg) { cols.empty? }
      end
      
      private
        def glue_columns(columns)
          cols = []
          cols << columns if columns.class == String
          cols += columns if columns.class == Array
          cols
        end
      
        def find_record_in_template(key = nil)
          response = acquire_assertion_target

          assert_template_has(key)
          record = response.template_objects[key]

          assert_not_nil(record)
          assert_kind_of ActiveRecord::Base, record

          return record
        end      
    end
  end
end