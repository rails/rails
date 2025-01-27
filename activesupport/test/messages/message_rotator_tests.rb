# frozen_string_literal: true

require "json"

module MessageRotatorTests
  extend ActiveSupport::Concern

  included do
    test "rotate secret" do
      assert_rotate [secret("new")], [secret("old")], [secret("older")]
    end

    test "rotate secret when message has purpose" do
      assert_rotate [secret("new")], [secret("old")], purpose: "purpose"
    end

    test "rotate url_safe" do
      assert_rotate [url_safe: true], [url_safe: false]
    end

    test "rotate serializer" do
      assert_rotate [serializer: JSON], [serializer: Marshal]
    end

    test "rotate serializer when message has purpose" do
      assert_rotate [serializer: JSON], [serializer: Marshal], purpose: "purpose"
    end

    test "rotate serializer that raises a custom deserialization error" do
      serializer = Class.new do
        def self.dump(*); ""; end
        def self.load(*); raise Class.new(StandardError); end
      end

      assert_rotate [serializer: serializer], [serializer: JSON], [serializer: Marshal]
    end

    test "rotate secret and options" do
      assert_rotate [secret("new"), url_safe: true], [secret("old"), url_safe: false]
    end

    test "on_rotation is called on successful rotation" do
      called = nil
      assert_rotate [secret("new"), on_rotation: proc { called = true }], [secret("old")]
      assert called
    end

    test "rotate().on_rotation is called on successful rotation" do
      called = nil
      codec = make_codec(secret("new")).rotate(secret("old")).on_rotation do
        called = true
      end
      old_codec = make_codec(secret("old"))
      old_message = encode(DATA, old_codec)
      assert_equal DATA, decode(old_message, codec)
      assert called
    end

    test "on_rotation is not called when no rotation is necessary" do
      called = nil
      assert_rotate [secret("same"), on_rotation: proc { called = true }], [secret("same")]
      assert_not called
    end

    test "on_rotation is not called when no rotation is successful" do
      called = nil
      codec = make_codec(secret("new"), on_rotation: proc { called = true })
      codec.rotate(secret("old"))
      other_message = encode(DATA, make_codec(secret("other")))

      assert_nil decode(other_message, codec)
      assert_not called
    end

    test "on_rotation method option takes precedence over constructor option" do
      called = ""
      codec = make_codec(secret("new"), on_rotation: proc { called += "via constructor" })
      codec.rotate(secret("old"))
      old_message = encode(DATA, make_codec(secret("old")))

      assert_equal DATA, decode(old_message, codec, on_rotation: proc { called += "via method" })
      assert_equal "via method", called
    end
  end

  private
    DATA = [{ "a_boolean" => true, "a_number" => 123, "a_string" => "abc" }]

    def secret(key)
      key
    end

    def assert_rotate(current, *old, **message_metadata)
      current_options = current.extract_options!
      current_codec = make_codec(*current, **current_options)

      old.each do |old_args|
        old_options = old_args.extract_options!
        current_codec.rotate(*old_args, **old_options)
        old_codec = make_codec(*old_args, **old_options)
        old_message = encode(DATA, old_codec, **message_metadata)

        assert_equal DATA, decode(old_message, current_codec, **message_metadata)
        assert_nil decode(old_message, current_codec) if !message_metadata.empty?
      end
    end
end
