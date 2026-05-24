# frozen_string_literal: true

require "test_helper"

class ActiveStorage::ClassIndirectionTest < ActiveSupport::TestCase
  class CustomBlob; end
  class CustomAttachment; end
  class CustomVariantRecord; end

  setup do
    @blob_class = ActiveStorage.blob_class
    @attachment_class = ActiveStorage.attachment_class
    @variant_record_class = ActiveStorage.variant_record_class
  end

  teardown do
    ActiveStorage.blob_class = @blob_class
    ActiveStorage.attachment_class = @attachment_class
    ActiveStorage.variant_record_class = @variant_record_class
  end

  test "defaults to active storage records" do
    assert_equal ActiveStorage::Blob, ActiveStorage.blob_class
    assert_equal ActiveStorage::Attachment, ActiveStorage.attachment_class
    assert_equal ActiveStorage::VariantRecord, ActiveStorage.variant_record_class
  end

  test "accepts class name overrides" do
    ActiveStorage.blob_class = "ActiveStorage::ClassIndirectionTest::CustomBlob"
    ActiveStorage.attachment_class = "ActiveStorage::ClassIndirectionTest::CustomAttachment"
    ActiveStorage.variant_record_class = "ActiveStorage::ClassIndirectionTest::CustomVariantRecord"

    assert_equal CustomBlob, ActiveStorage.blob_class
    assert_equal CustomAttachment, ActiveStorage.attachment_class
    assert_equal CustomVariantRecord, ActiveStorage.variant_record_class
  end

  test "accepts class overrides" do
    ActiveStorage.blob_class = CustomBlob
    ActiveStorage.attachment_class = CustomAttachment
    ActiveStorage.variant_record_class = CustomVariantRecord

    assert_equal CustomBlob, ActiveStorage.blob_class
    assert_equal CustomAttachment, ActiveStorage.attachment_class
    assert_equal CustomVariantRecord, ActiveStorage.variant_record_class
  end

  test "rejects anonymous class overrides" do
    error = assert_raises(ArgumentError) do
      ActiveStorage.blob_class = Class.new
    end

    assert_match "named class", error.message
  end

  test "clears memoized class resolutions" do
    ActiveStorage.blob_class = CustomBlob
    assert_equal CustomBlob, ActiveStorage.blob_class

    ActiveStorage.blob_class = "ActiveStorage::Blob"
    assert_equal ActiveStorage::Blob, ActiveStorage.blob_class
  end
end
