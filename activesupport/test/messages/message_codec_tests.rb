# frozen_string_literal: true

require "json"
require "active_support/core_ext/object/with"

module MessageCodecTests
  extend ActiveSupport::Concern

  included do
    test "::default_serializer determines the default serializer" do
      ActiveSupport::Messages::Codec.with(default_serializer: Marshal) do
        assert_serializer Marshal, make_codec
      end

      ActiveSupport::Messages::Codec.with(default_serializer: JSON) do
        assert_serializer JSON, make_codec
      end
    end

    test ":serializer option resolves symbols via SerializerWithFallback" do
      [:marshal, :json, :json_allow_marshal].each do |symbol|
        assert_serializer ActiveSupport::Messages::SerializerWithFallback[symbol], make_codec(serializer: symbol)
      end
    end
  end

  private
    def assert_serializer(serializer, codec)
      assert_equal serializer, codec.send(:serializer)
    end
end
