# frozen_string_literal: true

require "cases/encryption/helper"
require "base64"

class ActiveRecord::Encryption::MessageSerializerTest < ActiveRecord::EncryptionTestCase
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
    class_loading_payload = JSON.dump({ p: ::Base64.strict_encode64("Some payload"), json_class: "MessageSerializerTest::SomeClassThatWillNeverExist" })

    assert_raises(ArgumentError) { JSON.load(class_loading_payload) }
    assert_nothing_raised { @serializer.load(class_loading_payload) }
  end

  test "detects random JSON data and raises a decryption error" do
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      @serializer.load JSON.dump("hey there")
    end
  end

  test "detects random JSON hashes and raises a decryption error" do
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      @serializer.load JSON.dump({ some: "other data" })
    end
  end

  test "detects JSON hashes with a 'p' key that is not encoded in base64" do
    assert_raises ActiveRecord::Encryption::Errors::Encoding do
      @serializer.load JSON.dump({ p: "some data not encoded" })
    end
  end

  test "raises a TypeError when trying to deserialize other data types" do
    assert_raises TypeError do
      @serializer.load(:it_can_only_deserialize_strings)
    end
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
