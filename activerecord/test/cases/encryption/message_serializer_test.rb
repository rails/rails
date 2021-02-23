require "test_helper"

class ActiveRecord::Encryption::MessageSerializerTest < ActiveSupport::TestCase
  setup do
    @serializer = ActiveRecord::Encryption::MessageSerializer.new
  end

  test "serializes messages" do
    message = build_message
    deserialized_message = serialize_and_deserialize(message)
    assert_equal message, deserialized_message
  end

  test "serializes messages with nested messages in their headers" do
    message = build_message
    message.headers[:other_message] = ActiveRecord::Encryption::Message.new(payload: "some other secret payload", headers: { some_header: "some other value" })

    deserialized_message = serialize_and_deserialize(message)
    assert_equal message, deserialized_message
  end

  test "won't load classes from JSON" do
    class_loading_payload = '{"json_class": "MessageSerializerTest::SomeClassThatWillNeverExist"}'

    assert_raises(ArgumentError) { JSON.load(class_loading_payload) }
    assert_nothing_raised { @serializer.load(class_loading_payload) }
  end

  test "raises ForbiddenClass when trying to serialize other data types" do
    assert_raises ActiveRecord::Encryption::Errors::ForbiddenClass do
      @serializer.dump("it can only serialize messages!")
    end
  end

  test "raises Decryption when trying to parse message with more than one nested message" do
    message = build_message
    message.headers[:other_message] = ActiveRecord::Encryption::Message.new(payload: "some other secret payload", headers: { some_header: "some other value" })
    message.headers[:other_message].headers[:yet_another_message] = ActiveRecord::Encryption::Message.new(payload: "yet some other secret payload", headers: { some_header: "yet some other value" })

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      serialize_and_deserialize(message)
    end
  end

  private
    def build_message
      payload = "some payload"
      headers = { key_1: "1" }
      ActiveRecord::Encryption::Message.new(payload: payload, headers: headers)
    end

    def serialize_and_deserialize(message, with: @serializer)
      @serializer.load @serializer.dump(message)
    end
end