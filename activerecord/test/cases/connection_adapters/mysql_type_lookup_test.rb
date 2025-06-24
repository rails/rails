# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class MysqlTypeLookupTest < ActiveRecord::TestCase
      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        include ConnectionHelper

        setup do
          @connection = ActiveRecord::Base.lease_connection
        end

        def teardown
          reset_connection
        end

        def test_boolean_types
          emulate_booleans(true) do
            assert_lookup_type :boolean, "tinyint(1)"
            assert_lookup_type :boolean, "TINYINT(1)"
          end
        end

        def test_string_types
          assert_lookup_type :string, "enum('one', 'two', 'three')"
          assert_lookup_type :string, "ENUM('one', 'two', 'three')"
          assert_lookup_type :string, "enum ('one', 'two', 'three')"
          assert_lookup_type :string, "ENUM ('one', 'two', 'three')"
          assert_lookup_type :string, "set('one', 'two', 'three')"
          assert_lookup_type :string, "SET('one', 'two', 'three')"
          assert_lookup_type :string, "set ('one', 'two', 'three')"
          assert_lookup_type :string, "SET ('one', 'two', 'three')"
        end

        def test_set_type_with_value_matching_other_type
          assert_lookup_type :string, "SET('unicode', '8bit', 'none', 'time')"
        end

        def test_enum_type_with_value_matching_other_type
          assert_lookup_type :string, "ENUM('unicode', '8bit', 'none', 'time')"
        end

        def test_binary_types
          assert_lookup_type :binary, "bit"
          assert_lookup_type :binary, "BIT"
        end

        def test_integer_types
          emulate_booleans(false) do
            assert_lookup_type :integer, "tinyint(1)"
            assert_lookup_type :integer, "TINYINT(1)"
            assert_lookup_type :integer, "year"
            assert_lookup_type :integer, "YEAR"
          end
        end

        private
          def assert_lookup_type(type, lookup)
            cast_type = @connection.send(:type_map).lookup(lookup)
            assert_equal type, cast_type.type
          end

          def emulate_booleans(value)
            old_emulate_booleans = @connection.emulate_booleans
            change_emulate_booleans(value)
            yield
          ensure
            change_emulate_booleans(old_emulate_booleans)
          end

          def change_emulate_booleans(value)
            @connection.emulate_booleans = value
            @connection.clear_cache!
          end
      end
    end
  end
end
