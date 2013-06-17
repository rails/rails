require "cases/helper"

module ActiveRecord
  module AttributeMethods
    class SerializationTest < ActiveSupport::TestCase
      class FakeColumn < Struct.new(:name)
        def type; :integer; end
        def type_cast(s); "#{s}!"; end
      end

      class NullCoder
        def load(v); v; end
      end

      def test_type_cast_serialized_value
        value = Serialization::Attribute.new(NullCoder.new, "Hello world", :serialized)
        type = Serialization::Type.new(FakeColumn.new)
        assert_equal "Hello world!", type.type_cast(value)
      end

      def test_type_cast_unserialized_value
        value = Serialization::Attribute.new(nil, "Hello world", :unserialized)
        type = Serialization::Type.new(FakeColumn.new)
        type.type_cast(value)
        assert_equal "Hello world", type.type_cast(value)
      end
    end
  end
end
