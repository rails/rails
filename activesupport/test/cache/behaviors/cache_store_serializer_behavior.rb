# frozen_string_literal: true

require "active_support/core_ext/object/with"

module CacheStoreSerializerBehavior
  extend ActiveSupport::Concern

  included do
    test "serializer can be specified" do
      serializer = Module.new do
        def self.dump(value)
          value.class.name
        end

        def self.load(dumped)
          Object.const_get(dumped)
        end
      end

      @cache = with_format(7.1) { lookup_store(serializer: serializer) }
      key = "key#{rand}"

      @cache.write(key, 123)
      assert_equal Integer, @cache.read(key)
    end

    test "serializer can be :message_pack" do
      @cache = with_format(7.1) { lookup_store(serializer: :message_pack) }
      key = "key#{rand}"

      @cache.write(key, 123)
      assert_equal 123, @cache.read(key)

      assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
        @cache.write(key, Object.new)
      end
    end

    test "specifying a serializer raises when also specifying a coder" do
      with_format(7.1) do
        assert_raises ArgumentError, match: /serializer/i do
          lookup_store(serializer: Marshal, coder: Marshal)
        end
      end
    end
  end
end
