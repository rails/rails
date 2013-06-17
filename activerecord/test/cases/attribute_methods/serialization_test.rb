require "cases/helper"

module ActiveRecord
  module AttributeMethods
    class SerializationTest < ActiveSupport::TestCase
      class FakeColumn < Struct.new(:name)
        def type; :integer; end
        def type_cast(s); "#{s}!"; end
      end

      def test_type_cast_serialized_value
        value = stub(state: :serialized, value: "Hello world")
        value.expects(:unserialized_value).with("Hello world!")

        type = Serialization::Type.new(FakeColumn.new)
        type.type_cast(value)
      end

      def test_type_cast_unserialized_value
        value = stub(state: :unserialized, value: "Hello world")
        value.expects(:unserialized_value).with()

        type = Serialization::Type.new(FakeColumn.new)
        type.type_cast(value)
      end
    end
  end
end
