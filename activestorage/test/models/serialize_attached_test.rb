# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(name: "Josh")
  end

  teardown { ActiveStorage::Blob.all.each(&:purge) }

  test "serializing a object without attachments" do
    # the serialize_attachments method was used to indicate that :avatar and :cover_photo will be included in the serialization
    assert_equal true, @user.as_json.has_key?("avatar_attached")
    assert_equal true, @user.as_json.has_key?("cover_photo_attached")
    assert_equal false, @user.as_json.has_key?("highlights")
    assert_equal false, @user.as_json.has_key?("vlogs")
  end

  test "serializing a object with attachments" do
    # attach blob before messing with getter, which breaks `#attach`
    @user.avatar.attach create_blob(filename: "funky.jpg")

    assert_not_nil @user.as_json.has_value?("avatar_attached")
  end
end
