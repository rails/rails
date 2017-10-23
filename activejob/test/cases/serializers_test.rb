# frozen_string_literal: true

require "helper"
require "active_job/serializers"

class SerializersTest < ActiveSupport::TestCase
  class DummyValueObject
    attr_accessor :value

    def initialize(value)
      @value = value
    end
  end

  class DummySerializer < ActiveJob::Serializers::ObjectSerializer
    class << self
      def serialize(object)
        { key => object.value }
      end

      def deserialize(hash)
        DummyValueObject.new(hash[key])
      end

      def key
        "_dummy_serializer"
      end

      private

      def klass
        DummyValueObject
      end
    end
  end

  setup do
    @value_object = DummyValueObject.new 123
    ActiveJob::Base._additional_serializers = []
  end

  test "can't serialize unknown object" do
    assert_raises ActiveJob::SerializationError do
      ActiveJob::Serializers.serialize @value_object
    end
  end

  test "won't deserialize unknown hash" do
    hash = { "_dummy_serializer" => 123, "_aj_symbol_keys" => [] }
    assert ActiveJob::Serializers.deserialize(hash), hash.except("_aj_symbol_keys")
  end

  test "adds new serializer" do
    ActiveJob::Base.add_serializers DummySerializer
    assert ActiveJob::Base.serializers.include?(DummySerializer)
  end

  test "can't add serializer with the same key twice" do
    ActiveJob::Base.add_serializers DummySerializer
    assert_raises ArgumentError do
      ActiveJob::Base.add_serializers DummySerializer
    end
  end
end
