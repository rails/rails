# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/messages/serializer_with_fallback"

class MessagesSerializerWithFallbackTest < ActiveSupport::TestCase
  test ":marshal serializer dumps objects using Marshal format" do
    assert_roundtrip serializer(:marshal), Marshal
  end

  test ":json serializer dumps objects using JSON format" do
    assert_roundtrip serializer(:json), ActiveSupport::JSON
    assert_roundtrip serializer(:json_allow_marshal), ActiveSupport::JSON
  end

  test ":message_pack serializer dumps objects using MessagePack format" do
    assert_roundtrip serializer(:message_pack), ActiveSupport::MessagePack
    assert_roundtrip serializer(:message_pack_allow_marshal), ActiveSupport::MessagePack
  end

  test "every serializer can load every non-Marshal format" do
    (FORMATS - [:marshal]).product(FORMATS) do |dumping, loading|
      assert_roundtrip serializer(dumping), serializer(loading)
    end
  end

  test "only :marshal and :*_allow_marshal serializers can load Marshal format" do
    marshal_loading_formats = FORMATS.grep(/(?:\A|_allow_)marshal/)
    assert_operator marshal_loading_formats.length, :>, 1

    marshal_loading_formats.each do |loading|
      assert_roundtrip serializer(:marshal), serializer(loading)
    end

    marshalled = serializer(:marshal).dump({})

    (FORMATS - marshal_loading_formats).each do |loading|
      assert_raises(match: /unsupported/i) do
        serializer(loading).load(marshalled)
      end
    end
  end

  test ":json serializer recognizes regular JSON" do
    [
      nil, false, true,
      0, 1, -1,
      0.0, 1.0, -1.0, 0.1, -0.1,
      "", [], {},
    ].each do |value|
      dumped = serializer(:json).dump(value)
      assert serializer(:json).dumped?(dumped)
    end
  end

  test ":json serializer can load irregular JSON" do
    value = { "foo" => "bar" }
    dumped = serializer(:json).dump(value)

    assert_equal value, serializer(:json).load(" /* comment */ #{dumped}")
  end

  test "notifies when serializer falls back to loading an alternate format" do
    value = { "foo" => "bar" }
    dumped = serializer(:json).dump(value)

    payloads = []
    callback = -> (*args) { payloads << args.extract_options! }
    ActiveSupport::Notifications.subscribed(callback, "message_serializer_fallback.active_support") do
      serializer(:marshal).load(dumped)
    end

    assert_equal 1, payloads.length
    assert_equal :marshal, payloads.first[:serializer]
    assert_equal :json, payloads.first[:fallback]
    assert_equal dumped, payloads.first[:serialized]
    assert_equal value, payloads.first[:deserialized]
  end

  test "raises on invalid format name" do
    assert_raises KeyError do
      ActiveSupport::Messages::SerializerWithFallback[:invalid_format]
    end
  end

  private
    FORMATS = ActiveSupport::Messages::SerializerWithFallback::SERIALIZERS.keys

    def serializer(format)
      ActiveSupport::Messages::SerializerWithFallback[format]
    end

    def assert_roundtrip(serializer, deserializer = serializer)
      value = [{ "a_boolean" => false, "a_number" => 123 }]
      assert_equal value, deserializer.load(serializer.dump(value))
    end
end
