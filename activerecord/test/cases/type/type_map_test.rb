# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Type
    module TypeMapSharedTests
      def test_default_type
        mapping = klass.new

        assert_kind_of Value, mapping.lookup(:undefined)
      end

      def test_requires_value_or_block
        mapping = klass.new

        assert_raises(ArgumentError) do
          mapping.register_type(/only key/i)
        end
      end

      def test_fetch
        mapping = klass.new
        mapping.register_type(1, "string")

        assert_equal "string", mapping.fetch(1) { "int" }
        assert_equal "int", mapping.fetch(2) { "int" }
      end

      def test_fetch_memoizes
        mapping = klass.new

        looked_up = false
        mapping.register_type(1) do
          fail if looked_up
          looked_up = true
          "string"
        end

        assert_equal "string", mapping.fetch(1)
        assert_equal "string", mapping.fetch(1)
      end

      def test_register_clears_cache
        mapping = klass.new

        mapping.register_type(1, "string")
        mapping.lookup(1)
        mapping.register_type(1, "int")

        assert_equal "int", mapping.lookup(1)
      end
    end

    class TypeMapTest < ActiveRecord::TestCase
      include TypeMapSharedTests

      def test_registering_types
        boolean = Boolean.new
        mapping = klass.new

        mapping.register_type(/boolean/i, boolean)

        assert_equal mapping.lookup("boolean"), boolean
      end

      def test_overriding_registered_types
        time = Time.new
        timestamp = DateTime.new
        mapping = klass.new

        mapping.register_type(/time/i, time)
        mapping.register_type(/time/i, timestamp)

        assert_equal mapping.lookup("time"), timestamp
      end

      def test_aliasing_types
        string = +""
        mapping = klass.new

        mapping.register_type(/string/i, string)
        mapping.alias_type(/varchar/i, "string")

        assert_equal mapping.lookup("varchar"), string
      end

      def test_changing_type_changes_aliases
        time = Time.new
        timestamp = DateTime.new
        mapping = klass.new

        mapping.register_type(/timestamp/i, time)
        mapping.alias_type(/datetime/i, "timestamp")
        mapping.register_type(/timestamp/i, timestamp)

        assert_equal timestamp, mapping.lookup("datetime")
      end

      def test_aliases_keep_metadata
        mapping = klass.new

        mapping.register_type(/decimal/i) { |sql_type| sql_type }
        mapping.alias_type(/number/i, "decimal")

        assert_equal "decimal(20)", mapping.lookup("number(20)")
        assert_equal "decimal", mapping.lookup("number")
      end

      def test_fuzzy_lookup
        string = +""
        mapping = klass.new

        mapping.register_type(/varchar/i, string)

        assert_equal mapping.lookup("varchar(20)"), string
      end

      def test_register_proc
        string = +""
        binary = Binary.new
        mapping = klass.new

        mapping.register_type(/varchar/i) do |type|
          if type.include?("(")
            string
          else
            binary
          end
        end

        assert_equal mapping.lookup("varchar(20)"), string
        assert_equal mapping.lookup("varchar"), binary
      end

      def test_parent_fallback
        boolean = Boolean.new

        parent = klass.new
        parent.register_type(/boolean/i, boolean)

        mapping = klass.new(parent)
        assert_equal boolean, mapping.lookup("boolean")
      end

      def test_parent_fallback_for_default_type
        parent = klass.new
        mapping = klass.new(parent)

        assert_kind_of Value, mapping.lookup(:undefined)
      end

      private
        def klass
          TypeMap
        end
    end

    class HashLookupTypeMapTest < ActiveRecord::TestCase
      include TypeMapSharedTests

      def test_additional_lookup_args
        mapping = HashLookupTypeMap.new

        mapping.register_type("varchar") do |type, limit|
          if limit > 255
            "text"
          else
            "string"
          end
        end
        mapping.alias_type("string", "varchar")

        assert_equal "string", mapping.lookup("varchar", 200)
        assert_equal "text", mapping.lookup("varchar", 400)
        assert_equal "text", mapping.lookup("string", 400)
      end

      def test_lookup_non_strings
        mapping = HashLookupTypeMap.new

        mapping.register_type(1, "string")
        mapping.register_type(2, "int")
        mapping.alias_type(3, 1)

        assert_equal "string", mapping.lookup(1)
        assert_equal "int", mapping.lookup(2)
        assert_equal "string", mapping.lookup(3)
        assert_kind_of Type::Value, mapping.lookup(4)
      end

      def test_fetch_memoizes_on_args
        mapping = HashLookupTypeMap.new
        mapping.register_type("foo") { |*args| args.join("-") }

        assert_equal "foo-1-2-3", mapping.fetch("foo", 1, 2, 3) { |*args| args.join("-") }
        assert_equal "foo-2-3-4", mapping.fetch("foo", 2, 3, 4) { |*args| args.join("-") }
      end

      def test_fetch_yields_args
        mapping = klass.new

        assert_equal "foo-1-2-3", mapping.fetch("foo", 1, 2, 3) { |*args| args.join("-") }
        assert_equal "bar-1-2-3", mapping.fetch("bar", 1, 2, 3) { |*args| args.join("-") }
      end

      private
        def klass
          HashLookupTypeMap
        end
    end
  end
end
