# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentTest < ActiveSupport::TestCase
  test "generating a variant using transformations" do
    blob = create_file_blob(filename: "racecar.jpg")
    record = create_user
    attachment = create_attachment(record: record, name: "cover_photo", blob: blob)

    variant = attachment.variant(resize: "100x100").processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "generating a variant using a variant name" do
    blob = create_file_blob(filename: "racecar.jpg")
    record = create_user
    attachment = create_attachment(record: record, name: "cover_photo", blob: blob)

    variant = attachment.variant(:thumbnail).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "generating a variant using a variant name that is not defined" do
    blob = create_file_blob(filename: "racecar.jpg")
    record = create_user
    attachment = create_attachment(record: record, name: "cover_photo", blob: blob)

    assert_raise(ActiveStorage::UndefinedVariant) do
      attachment.variant(:undefined_variant_name)
    end
  end
end
