require "cases/helper"

module ActiveRecord
  module Type
    class TypeMapTest < ActiveRecord::TestCase
      def test_default_type
        mapping = TypeMap.new

        assert_kind_of Value, mapping.lookup(:undefined)
      end

      def test_registering_types
        boolean = Boolean.new
        mapping = TypeMap.new

        mapping.register_type(/boolean/i, boolean)

        assert_equal mapping.lookup("boolean"), boolean
      end

      def test_overriding_registered_types
        time = Time.new
        timestamp = DateTime.new
        mapping = TypeMap.new

        mapping.register_type(/time/i, time)
        mapping.register_type(/time/i, timestamp)

        assert_equal mapping.lookup("time"), timestamp
      end

      def test_fuzzy_lookup
        string = String.new
        mapping = TypeMap.new

        mapping.register_type(/varchar/i, string)

        assert_equal mapping.lookup("varchar(20)"), string
      end

      def test_aliasing_types
        string = String.new
        mapping = TypeMap.new

        mapping.register_type(/string/i, string)
        mapping.alias_type(/varchar/i, "string")

        assert_equal mapping.lookup("varchar"), string
      end

      def test_changing_type_changes_aliases
        time = Time.new
        timestamp = DateTime.new
        mapping = TypeMap.new

        mapping.register_type(/timestamp/i, time)
        mapping.alias_type(/datetime/i, "timestamp")
        mapping.register_type(/timestamp/i, timestamp)

        assert_equal mapping.lookup("datetime"), timestamp
      end

      def test_aliases_keep_metadata
        mapping = TypeMap.new

        mapping.register_type(/decimal/i) { |sql_type| sql_type }
        mapping.alias_type(/number/i, "decimal")

        assert_equal mapping.lookup("number(20)"), "decimal(20)"
        assert_equal mapping.lookup("number"), "decimal"
      end

      def test_register_proc
        string = String.new
        binary = Binary.new
        mapping = TypeMap.new

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

      def test_additional_lookup_args
        mapping = TypeMap.new

        mapping.register_type(/varchar/i) do |type, limit|
          if limit > 255
            "text"
          else
            "string"
          end
        end
        mapping.alias_type(/string/i, "varchar")

        assert_equal mapping.lookup("varchar", 200), "string"
        assert_equal mapping.lookup("varchar", 400), "text"
        assert_equal mapping.lookup("string", 400), "text"
      end

      def test_requires_value_or_block
        mapping = TypeMap.new

        assert_raises(ArgumentError) do
          mapping.register_type(/only key/i)
        end
      end

      def test_lookup_non_strings
        mapping = HashLookupTypeMap.new

        mapping.register_type(1, "string")
        mapping.register_type(2, "int")
        mapping.alias_type(3, 1)

        assert_equal mapping.lookup(1), "string"
        assert_equal mapping.lookup(2), "int"
        assert_equal mapping.lookup(3), "string"
        assert_kind_of Type::Value, mapping.lookup(4)
      end

      def test_fetch
        mapping = TypeMap.new
        mapping.register_type(1, "string")

        assert_equal "string", mapping.fetch(1) { "int" }
        assert_equal "int", mapping.fetch(2) { "int" }
      end

      def test_fetch_yields_args
        mapping = TypeMap.new

        assert_equal "foo-1-2-3", mapping.fetch("foo", 1, 2, 3) { |*args| args.join("-") }
        assert_equal "bar-1-2-3", mapping.fetch("bar", 1, 2, 3) { |*args| args.join("-") }
      end

      def test_fetch_memoizes
        mapping = TypeMap.new

        looked_up = false
        mapping.register_type(1) do
          fail if looked_up
          looked_up = true
          "string"
        end

        assert_equal "string", mapping.fetch(1)
        assert_equal "string", mapping.fetch(1)
      end

      def test_fetch_memoizes_on_args
        mapping = TypeMap.new
        mapping.register_type("foo") { |*args| args.join("-") }

        assert_equal "foo-1-2-3", mapping.fetch("foo", 1, 2, 3) { |*args| args.join("-") }
        assert_equal "foo-2-3-4", mapping.fetch("foo", 2, 3, 4) { |*args| args.join("-") }
      end

      def test_register_clears_cache
        mapping = TypeMap.new

        mapping.register_type(1, "string")
        mapping.lookup(1)
        mapping.register_type(1, "int")

        assert_equal "int", mapping.lookup(1)
      end
    end
  end
end

