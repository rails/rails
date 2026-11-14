# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentPrefixTest < ActiveSupport::TestCase
  TOKEN = /[a-z0-9]{#{ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH}}/

  setup do
    @user = PrefixedUser.create!(name: "Josh", group_id: 42)
  end

  teardown do
    ActiveStorage::Blob.all.each(&:delete)
  end

  test "generating a key without prefixes" do
    assert_match(/\A#{TOKEN}\z/, ActiveStorage::Blob.generate_unique_key)
  end

  test "generating a key with the global prefix" do
    with_blob_prefix("active_storage") do
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key)
    end
  end

  test "generating a key with the global prefix and a prefix" do
    with_blob_prefix("active_storage") do
      assert_match(%r{\Aactive_storage/avatars/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key(prefix: "avatars"))
      assert_match(%r{\Aactive_storage/42/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key(prefix: 42))
    end
  end

  test "generating a key with an array of prefixes" do
    with_blob_prefix("active_storage") do
      assert_match(%r{\Aactive_storage/tenants/42/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key(prefix: [ "tenants", 42 ]))
      assert_match(%r{\Aactive_storage/42/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key(prefix: [ nil, 42 ]))
    end
  end

  test "generating a key ignores surrounding slashes and empty segments" do
    with_blob_prefix("/active_storage/") do
      assert_match(%r{\Aactive_storage/tenants/42/#{TOKEN}\z}, ActiveStorage::Blob.generate_unique_key(prefix: "/tenants//42/"))
    end
  end

  test "generating a key ignores blank prefixes" do
    with_blob_prefix("") do
      assert_match(/\A#{TOKEN}\z/, ActiveStorage::Blob.generate_unique_key(prefix: nil))
      assert_match(/\A#{TOKEN}\z/, ActiveStorage::Blob.generate_unique_key(prefix: " "))
    end
  end

  test "generating a key with dot segments raises" do
    assert_raises(ActiveStorage::InvalidKeyError) { ActiveStorage::Blob.generate_unique_key(prefix: "../secrets") }
    assert_raises(ActiveStorage::InvalidKeyError) { ActiveStorage::Blob.generate_unique_key(prefix: "tenants/./42") }

    with_blob_prefix("..") do
      assert_raises(ActiveStorage::InvalidKeyError) { ActiveStorage::Blob.generate_unique_key }
    end
  end

  test "creating a blob uses the global prefix" do
    with_blob_prefix("active_storage") do
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, create_blob.key)
    end
  end

  test "creating a blob before a direct upload uses the global prefix" do
    with_blob_prefix("active_storage") do
      blob = create_blob_before_direct_upload(byte_size: 12, checksum: OpenSSL::Digest::MD5.base64digest("Hello world!"))
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, blob.key)
    end
  end

  test "creating a blob with a custom key ignores the global prefix" do
    with_blob_prefix("active_storage") do
      assert_equal "custom/key", create_blob(key: "custom/key").key
    end
  end

  test "attaching an uploaded file uses the attachment's prefix" do
    @user.avatar_with_prefix.attach fixture_file_upload("racecar.jpg")
    assert_match(%r{\Aavatars/#{TOKEN}\z}, @user.avatar_with_prefix.key)
  end

  test "attaching an uploaded file combines the global prefix and the attachment's prefix" do
    with_blob_prefix("active_storage") do
      @user.avatar_with_prefix.attach fixture_file_upload("racecar.jpg")
      assert_match(%r{\Aactive_storage/avatars/#{TOKEN}\z}, @user.avatar_with_prefix.key)
    end
  end

  test "attaching a Hash uses the attachment's prefix" do
    @user.avatar_with_prefix.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg"
    assert_match(%r{\Aavatars/#{TOKEN}\z}, @user.avatar_with_prefix.key)
  end

  test "attaching a Hash with a key keeps that key" do
    @user.avatar_with_prefix.attach io: StringIO.new("STUFF"), filename: "town.jpg", key: "custom/key"
    assert_equal "custom/key", @user.avatar_with_prefix.key
  end

  test "attaching a File uses the attachment's prefix" do
    @user.avatar_with_prefix.attach file_fixture("racecar.jpg").open
    assert_match(%r{\Aavatars/#{TOKEN}\z}, @user.avatar_with_prefix.key)
  end

  test "attaching a Pathname uses the attachment's prefix" do
    @user.avatar_with_prefix.attach file_fixture("racecar.jpg")
    assert_match(%r{\Aavatars/#{TOKEN}\z}, @user.avatar_with_prefix.key)
  end

  test "attaching an existing blob keeps its key" do
    blob = create_blob
    @user.avatar_with_prefix.attach blob
    assert_equal blob.key, @user.avatar_with_prefix.key
    assert_no_match(/avatars/, @user.avatar_with_prefix.key)
  end

  test "attaching a blob by signed ID keeps its key" do
    blob = create_blob
    @user.avatar_with_prefix.attach blob.signed_id
    assert_equal blob.key, @user.avatar_with_prefix.key
  end

  test "attaching files to a has_many_attached calls the prefix proc with the record" do
    @user.highlights_with_prefix.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
    assert_equal 2, @user.highlights_with_prefix.count
    @user.highlights_with_prefix.each do |highlight|
      assert_match(%r{\A42/#{TOKEN}\z}, highlight.key)
    end
  end

  test "attaching a file calls the prefix proc with the attachable" do
    @user.resume_with_prefix.attach fixture_file_upload("report.pdf")
    assert_match(%r{\Apdf/#{TOKEN}\z}, @user.resume_with_prefix.key)
  end

  test "attaching a file calls a one-argument prefix proc with the record" do
    @user.cover_photo_with_prefix.attach fixture_file_upload("racecar.jpg")
    assert_match(%r{\Agroups/42/#{TOKEN}\z}, @user.cover_photo_with_prefix.key)
  end

  test "creating a record evaluates the prefix after all attributes are assigned" do
    user = PrefixedUser.create!(highlights_with_prefix: [ fixture_file_upload("racecar.jpg") ], name: "Jason", group_id: 7)
    assert_match(%r{\A7/#{TOKEN}\z}, user.highlights_with_prefix.first.key)

    user = PrefixedUser.create!(avatar_with_prefix: fixture_file_upload("racecar.jpg"), cover_photo_with_prefix: fixture_file_upload("racecar.jpg"), name: "Jason", group_id: 7)
    assert_match(%r{\Agroups/7/#{TOKEN}\z}, user.cover_photo_with_prefix.key)
  end

  test "saving a record evaluates the prefix with attributes assigned after the attachable" do
    user = PrefixedUser.new(name: "Jason", highlights_with_prefix: [ fixture_file_upload("racecar.jpg") ])
    user.group_id = 7
    user.save!

    assert_match(%r{\A7/#{TOKEN}\z}, user.highlights_with_prefix.first.key)
  end

  test "attaching a file uploads it under the prefixed key" do
    user = PrefixedUser.new(name: "Jason", highlights_with_prefix: [ fixture_file_upload("racecar.jpg") ])
    user.group_id = 7
    user.save!

    blob = user.highlights_with_prefix.first.blob
    assert ActiveStorage::Blob.service.exist?(blob.key)
    assert_equal file_fixture("racecar.jpg").binread, blob.download
  end

  test "attaching a file when the prefix proc returns nil uses no attachment prefix" do
    user = PrefixedUser.create!(name: "Jason")
    user.highlights_with_prefix.attach fixture_file_upload("racecar.jpg")
    assert_match(/\A#{TOKEN}\z/, user.highlights_with_prefix.first.key)
  end

  test "attaching a file to an attachment without a prefix uses the global prefix" do
    with_blob_prefix("active_storage") do
      @user.avatar.attach fixture_file_upload("racecar.jpg")
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, @user.avatar.key)
    end
  end

  test "variants are stored under their blob's prefix" do
    with_blob_prefix("active_storage") do
      @user.avatar_with_prefix.attach fixture_file_upload("racecar.jpg")
      variant = @user.avatar_with_prefix.variant(resize_to_limit: [100, 100]).processed

      assert_match(%r{\Aactive_storage/avatars/#{TOKEN}\z}, variant.image.key)
      assert_not_equal @user.avatar_with_prefix.key, variant.image.key
    end
  end

  test "variants of a blob without a prefix use the global prefix" do
    blob = create_file_blob(filename: "racecar.jpg")

    with_blob_prefix("active_storage") do
      variant = blob.variant(resize_to_limit: [100, 100]).processed
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, variant.image.key)
    end
  end

  test "generating a derived key for a blob with a custom key with dot segments" do
    blob = ActiveStorage::Blob.new(key: "uploads/./racecar")

    with_blob_prefix("active_storage") do
      assert_match(%r{\Aactive_storage/#{TOKEN}\z}, blob.generate_derived_key)
    end
  end

  test "previews are stored under their blob's prefix" do
    blob = create_file_blob(key: "active_storage/42/#{ActiveStorage::Blob.generate_unique_secure_token}", filename: "report.pdf", content_type: "application/pdf")
    preview = blob.preview(resize_to_limit: [640, 280]).processed

    assert_match(%r{\Aactive_storage/42/#{TOKEN}\z}, preview.image.key)
  end
end
