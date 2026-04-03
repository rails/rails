# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantOrSelfTest < ActiveSupport::TestCase
  test "returns passthrough variant when blob content type matches one of the accepted formats" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:png, :jpeg])

    assert_instance_of ActiveStorage::PassthroughVariant, result
  end

  test "returns variant converted to first format when blob content type does not match" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:png])

    assert_not_instance_of ActiveStorage::PassthroughVariant, result

    variant = result.processed
    assert_equal "image/png", variant.content_type
    assert_equal "racecar.png", variant.filename.to_s
  end

  test "passthrough variant does not trigger image processing" do
    blob = create_file_blob(filename: "racecar.jpg")

    events = []
    callback = ->(name, start, finish, id, payload) { events << { name: name, payload: payload } }
    ActiveSupport::Notifications.subscribed(callback, "transform.active_storage") do
      blob.variant_or_self(formats: [:jpeg, :png]).processed
    end

    assert_empty events, "Expected no image transformation for passthrough variant, got: #{events.inspect}"
  end

  test "passthrough variant responds to processed and returns self" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_same result, result.processed
  end

  test "passthrough variant delegates url to blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_match(/racecar\.jpg/, result.url)
  end

  test "passthrough variant delegates key to blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_equal blob.key, result.key
  end

  test "passthrough variant delegates download to blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_equal blob.download, result.download
  end

  test "passthrough variant returns blob filename" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_equal blob.filename, result.filename
  end

  test "passthrough variant returns blob content type" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_equal "image/jpeg", result.content_type
  end

  test "passthrough variant responds to image and returns self" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg])

    assert_same result, result.image
  end

  test "raises ArgumentError when extra transformations are provided" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_raises ArgumentError, match: /variant/ do
      blob.variant_or_self(formats: [:jpeg], resize_to_limit: [100, 100])
    end
  end

  test "raises ArgumentError when formats is empty" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_raises ArgumentError do
      blob.variant_or_self(formats: [])
    end
  end

  test "raises ArgumentError when formats is not provided" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_raises ArgumentError do
      blob.variant_or_self
    end
  end

  test "raises on invariable blob" do
    assert_raises ActiveStorage::InvariableError do
      create_file_blob(filename: "report.pdf", content_type: "application/pdf").variant_or_self(formats: [:png])
    end
  end

  test "matches first acceptable format in list" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:jpeg, :png])

    assert_instance_of ActiveStorage::PassthroughVariant, result
    assert_equal "image/jpeg", result.content_type
  end

  test "converts to first format in list when no match" do
    blob = create_file_blob(filename: "racecar.jpg")
    result = blob.variant_or_self(formats: [:png, :webp])

    variant = result.processed
    assert_equal "image/png", variant.content_type
  end
end
