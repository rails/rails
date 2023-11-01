# frozen_string_literal: true

require "active_support/json"
require "active_support/time"
require "active_support/messages/metadata"
require "active_support/message_pack"

module MessageMetadataTests
  extend ActiveSupport::Concern

  included do
    test "message :purpose must match specified :purpose" do
      each_scenario do |data, codec|
        assert_roundtrip data, codec, { purpose: "x" }, { purpose: "x" }

        assert_no_roundtrip data, codec, { purpose: "x" }, { purpose: "y" }
        assert_no_roundtrip data, codec, { purpose: "x" }, {}
        assert_no_roundtrip data, codec, {}, { purpose: "x" }
      end
    end

    test ":purpose can be a symbol" do
      each_scenario do |data, codec|
        assert_roundtrip data, codec, { purpose: :x }, { purpose: :x }
        assert_roundtrip data, codec, { purpose: :x }, { purpose: "x" }
        assert_roundtrip data, codec, { purpose: "x" }, { purpose: :x }
      end
    end

    test "message expires with :expires_at" do
      freeze_time do
        each_scenario do |data, codec|
          message = encode(data, codec, expires_at: 1.second.from_now)

          travel 0.5.seconds, with_usec: true
          assert_equal data, decode(message, codec)

          travel 0.5.seconds, with_usec: true
          assert_nil decode(message, codec)
        end
      end
    end

    test "message expires with :expires_in" do
      freeze_time do
        each_scenario do |data, codec|
          message = encode(data, codec, expires_in: 1.second)

          travel 0.5.seconds, with_usec: true
          assert_equal data, decode(message, codec)

          travel 0.5.seconds, with_usec: true
          assert_nil decode(message, codec)
        end
      end
    end

    test ":expires_at overrides :expires_in" do
      each_scenario do |data, codec|
        message = encode(data, codec, expires_at: 1.hour.from_now, expires_in: 1.second)

        travel 1.minute
        assert_equal data, decode(message, codec)

        travel 1.hour
        assert_nil decode(message, codec)
      end
    end

    test "messages do not expire by default" do
      each_scenario do |data, codec|
        message = encode(data, codec, purpose: "x")

        travel 1000.years
        assert_equal data, decode(message, codec, purpose: "x")
      end
    end

    test "expiration works with ActiveSupport.use_standard_json_time_format = false" do
      original_use_standard_json_time_format = ActiveSupport.use_standard_json_time_format
      ActiveSupport.use_standard_json_time_format = false

      each_scenario do |data, codec|
        assert_roundtrip data, codec, { expires_at: 1.hour.from_now }
      end
    ensure
      ActiveSupport.use_standard_json_time_format = original_use_standard_json_time_format
    end

    test "metadata works with NullSerializer" do
      codec = make_codec(serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      assert_roundtrip "a string", codec, { purpose: "x", expires_in: 1.year }, { purpose: "x" }
    end

    test "messages with non-string purpose are readable" do
      each_scenario do |data, codec|
        message = encode(data, codec, purpose: [ "x", 1 ])
        assert_equal data, decode(message, codec, purpose: [ "x", 1 ])
      end
    end

    test "messages are readable regardless of use_message_serializer_for_metadata" do
      each_scenario do |data, codec|
        message = encode(data, codec, purpose: "x")
        message_setting = ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata

        using_message_serializer_for_metadata(!message_setting) do
          assert_equal data, decode(message, codec, purpose: "x")
        end
      end
    end
  end

  private
    class CustomSerializer
      def self.dump(value)
        JSON.dump(value) << "!"
      end

      def self.load(value)
        JSON.load(value.chomp!("!"))
      end
    end

    SERIALIZERS = [
      Marshal,
      JSON,
      ActiveSupport::JSON,
      ActiveSupport::MessagePack,
      CustomSerializer,
    ]

    DATA = [
      "a string",
      { "a_number" => 123, "a_time" => Time.local(2004), "an_object" => { "key" => "value" } },
      ["a string", 123, Time.local(2004), { "key" => "value" }],
    ]

    def using_message_serializer_for_metadata(value = true)
      original = ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = value
      yield
    ensure
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = original
    end

    def each_scenario
      [false, true].each do |use_message_serializer_for_metadata|
        using_message_serializer_for_metadata(use_message_serializer_for_metadata) do
          SERIALIZERS.each do |serializer|
            codec = make_codec(serializer: serializer)
            DATA.each do |data|
              yield data, codec
            end
          end
        end
      end
    end

    def roundtrip(data, codec, encode_options = {}, decode_options = {})
      decode(encode(data, codec, **encode_options), codec, **decode_options)
    end

    def assert_roundtrip(data, codec, encode_options = {}, decode_options = {})
      assert_equal data, roundtrip(data, codec, encode_options, decode_options)
    end

    def assert_no_roundtrip(data, codec, encode_options = {}, decode_options = {})
      assert_nil roundtrip(data, codec, encode_options, decode_options)
    end
end
