# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BinaryTest < ActiveModel::TestCase
      def test_type_cast_binary
        type = Type::Binary.new

        assert_nil type.cast(nil)
        assert_equal 1, type.cast(1)

        assert_equal "1", type.cast("1")
        assert_equal Encoding::BINARY, type.cast("1").encoding

        assert_equal "ƒée".b, type.cast("ƒée")
        assert_not_equal "ƒée", type.cast("ƒée")
      end

      def test_serialize_binary_strings
        type = Type::Binary.new
        assert_equal "ƒée".b, type.serialize("ƒée")
        assert_not_equal "ƒée", type.serialize("ƒée")
      end

      def test_type_and_binary_predicate
        type = Type::Binary.new

        assert_equal :binary, type.type
        assert_predicate type, :binary?
      end

      def test_serialize_returns_binary_data
        type = Type::Binary.new

        assert_nil type.serialize(nil)
        assert_instance_of Type::Binary::Data, type.serialize("ƒée")
      end

      def test_cast_binary_data_returns_the_underlying_string
        type = Type::Binary.new
        data = type.serialize("ƒée")

        assert_equal "ƒée".b, type.cast(data)
        assert_equal Encoding::BINARY, type.cast(data).encoding
      end

      def test_changed_in_place
        type = Type::Binary.new

        assert type.changed_in_place?("old value", "new value")
        assert_not type.changed_in_place?("same value", "same value")
      end

      def test_data_hex_and_string_conversion
        data = Type::Binary::Data.new("\xFF\x00")

        assert_equal "ff00", data.hex
        assert_equal "\xFF\x00".b, data.to_s
        assert_equal "\xFF\x00".b, data.to_str
        assert_equal data, "\xFF\x00".b
      end

      def test_data_as_json
        data = Type::Binary::Data.new("\xFF\x00")

        assert_equal "\xFF\x00".b.as_json, data.as_json
      end
    end
  end
end
