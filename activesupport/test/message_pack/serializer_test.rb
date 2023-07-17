# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/message_pack"
require_relative "shared_serializer_tests"

class MessagePackSerializerTest < ActiveSupport::TestCase
  include MessagePackSharedSerializerTests

  test "raises friendly error when dumping an unsupported object" do
    assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
      dump(UnsupportedObject.new)
    end
  end

  private
    def serializer
      ActiveSupport::MessagePack
    end

    class UnsupportedObject; end
end
