# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_support/testing/method_call_assertions"

class ActiveStorage::BlobTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include ActiveJob::TestHelper

  test "unattached scope" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      User.create! name: "DHH", avatar: blobs.first
      assert_includes ActiveStorage::Blob.unattached, blobs.second
      assert_not_includes ActiveStorage::Blob.unattached, blobs.first

      User.create! name: "Jason", avatar: blobs.second
      assert_not_includes ActiveStorage::Blob.unattached, blobs.second
    end
  end

  test "create_and_upload does not permit a conflicting blob key to overwrite an existing object" do
    data = "First file"
    blob = create_blob data: data

    assert_raises ActiveRecord::RecordNotUnique do
      ActiveStorage::Blob.stub :generate_unique_secure_token, blob.key do
        create_blob data: "This would overwrite"
      end
    end

    assert_equal data, blob.download
  end

  test "create_and_upload sets byte size and checksum" do
    data = "Hello world!"
    blob = create_blob data: data

    assert_equal data, blob.download
    assert_equal data.length, blob.byte_size
    assert_equal ActiveStorage.checksum_implementation.base64digest(data), blob.checksum
  end

  test "create_and_upload extracts content type from data" do
    blob = create_file_blob fixture: "racecar.jpg", content_type: "application/octet-stream", filename: "spoofed.txt"
    assert_equal "image/jpeg", blob.content_type
  end

  test "create_and_upload prefers given content type over filename" do
    blob = create_blob content_type: "specific/type", filename: "file.txt"
    assert_equal "specific/type", blob.content_type
  end

  test "create_and_upload prefers filename over binary content type" do
    blob = create_blob content_type: "application/octet-stream", filename: "file.txt"
    assert_equal "text/plain", blob.content_type
  end

  test "create_and_upload extracts content type from filename" do
    blob = create_blob content_type: nil, filename: "hello.txt"
    assert_equal "text/plain", blob.content_type
  end

  test "create_and_upload extracts content_type from io when missing and identify: false" do
    blob = create_file_blob fixture: "racecar.jpg", content_type: nil, filename: "unknown", identify: false
    assert_equal "image/jpeg", blob.content_type
  end

  test "create_and_upload uses given content_type when identify: false" do
    blob = create_file_blob fixture: "racecar.jpg", content_type: "given/type", filename: "unknown", identify: false
    assert_equal "given/type", blob.content_type
  end

  test "create_and_upload generates a 28-character base36 key" do
    assert_match(/^[a-z0-9]{28}$/, create_blob.key)
  end

  test "create_and_upload accepts a custom key" do
    key  = SecureRandom.base36(28)
    data = "Hello world!"
    blob = create_blob key: key, data: data

    assert_equal key, blob.key
    assert_equal data, blob.download
  end

  test "create_and_upload accepts a record for overrides" do
    assert_nothing_raised do
      create_blob(record: User.new)
    end
  end

  test "create_and_upload raises for non-rewindable io" do
    assert_raises(ArgumentError) do
      ActiveStorage::Blob.create_and_upload!(io: file_fixture("racecar.jpg"), filename: "racecar.jpg")
    end
  end

  test "record touched after analyze" do
    user = User.create!(
      name: "Nate",
      avatar: {
        content_type: "image/jpeg",
        filename: "racecar.jpg",
        io: file_fixture("racecar.jpg").open,
      }
    )

    assert_changes -> { user.reload.updated_at } do
      user.avatar.blob.analyze
    end
  end

  test "build_after_unfurling generates a 28-character base36 key" do
    assert_match(/^[a-z0-9]{28}$/, build_blob_after_unfurling.key)
  end

  test "compose" do
    blobs = 3.times.map { create_blob(data: "123", filename: "numbers.txt", content_type: "text/plain", identify: false) }
    blob = ActiveStorage::Blob.compose(blobs, filename: "all_numbers.txt")

    assert_equal "123123123", blob.download
    assert_equal "text/plain", blob.content_type
    assert_equal blobs.first.byte_size * blobs.count, blob.byte_size
    assert_predicate(blob, :composed)
    assert_nil blob.checksum
  end

  test "compose with unpersisted blobs" do
    blobs = 3.times.map { create_blob(data: "123", filename: "numbers.txt", content_type: "text/plain", identify: false).dup }

    error = assert_raises(ActiveRecord::RecordNotSaved) do
      ActiveStorage::Blob.compose(blobs, filename: "all_numbers.txt")
    end
    assert_equal "All blobs must be persisted.", error.message
  end

  test "compose with custom key" do
    blobs = 3.times.map { create_blob(data: "123", filename: "numbers.txt", content_type: "text/plain", identify: false) }
    blob = ActiveStorage::Blob.compose(blobs, key: "custom_key", filename: "all_numbers.txt")

    assert_equal "custom_key", blob.key
    assert_equal "123123123", blob.download
  end

  test "image?" do
    blob = create_file_blob filename: "racecar.jpg"
    assert_predicate blob, :image?
    assert_not_predicate blob, :audio?
  end

  test "video?" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
    assert_predicate blob, :video?
    assert_not_predicate blob, :audio?
  end

  test "text?" do
    blob = create_blob data: "Hello world!"
    assert_predicate blob, :text?
    assert_not_predicate blob, :audio?
  end

  test "download yields chunks" do
    blob   = create_blob data: "a" * 5.0625.megabytes
    chunks = []

    blob.download do |chunk|
      chunks << chunk
    end

    assert_equal 2, chunks.size
    assert_equal "a" * 5.megabytes, chunks.first
    assert_equal "a" * 64.kilobytes, chunks.second
  end

  test "open with integrity" do
    create_file_blob(filename: "racecar.jpg").tap do |blob|
      blob.open do |file|
        assert_predicate file, :binmode?
        assert_equal 0, file.pos
        assert File.basename(file.path).start_with?("ActiveStorage-#{blob.id}-")
        assert file.path.end_with?(".jpg")
        assert_equal file_fixture("racecar.jpg").binread, file.read, "Expected downloaded file to match fixture file"
      end
    end
  end

  test "open without integrity" do
    create_blob(data: "Hello, world!").tap do |blob|
      blob.update! checksum: ActiveStorage.checksum_implementation.base64digest("Goodbye, world!")

      assert_raises ActiveStorage::IntegrityError do
        blob.open { |file| flunk "Expected integrity check to fail" }
      end
    end
  end

  test "open in a custom tmpdir" do
    create_file_blob(filename: "racecar.jpg").open(tmpdir: tmpdir = Dir.mktmpdir) do |file|
      assert_predicate file, :binmode?
      assert_equal 0, file.pos
      assert_match(/\.jpg\z/, file.path)
      assert file.path.start_with?(tmpdir)
      assert_equal file_fixture("racecar.jpg").binread, file.read, "Expected downloaded file to match fixture file"
    end
  end

  test "URLs expiring in 5 minutes" do
    blob = create_blob

    freeze_time do
      assert_equal expected_url_for(blob), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment), blob.url(disposition: :attachment)
    end
  end

  test "URLs force content_type to binary and attachment as content disposition for content types served as binary" do
    blob = create_blob(content_type: "text/html")

    freeze_time do
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/octet-stream"), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/octet-stream"), blob.url(disposition: :inline)
    end
  end

  test "URLs force attachment as content disposition when the content type is not allowed inline" do
    blob = create_blob(content_type: "application/zip")

    freeze_time do
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/zip"), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/zip"), blob.url(disposition: :inline)
    end
  end

  test "URLs allow for custom filename" do
    blob = create_blob(filename: "original.txt")
    new_filename = ActiveStorage::Filename.new("new.txt")

    freeze_time do
      assert_equal expected_url_for(blob), blob.url
      assert_equal expected_url_for(blob, filename: new_filename), blob.url(filename: new_filename)
      assert_equal expected_url_for(blob, filename: new_filename), blob.url(filename: "new.txt")
      assert_equal expected_url_for(blob, filename: blob.filename), blob.url(filename: nil)
    end
  end

  test "URLs allow for custom options" do
    blob = create_blob(filename: "original.txt")

    arguments = [
      blob.key
    ]

    kwargs = {
      expires_in: ActiveStorage.service_urls_expire_in,
      disposition: :attachment,
      content_type: blob.content_type,
      filename: blob.filename,
      thumb_size: "300x300",
      thumb_mode: "crop"
    }
    assert_called_with(blob.service, :url, arguments, **kwargs) do
      blob.url(thumb_size: "300x300", thumb_mode: "crop")
    end
  end

  test "purge deletes file from external service" do
    blob = create_blob

    blob.purge
    assert_not ActiveStorage::Blob.service.exist?(blob.key)
  end

  test "purge deletes variants from external service with the purge_later" do
    blob = create_file_blob
    variant = blob.variant(resize_to_limit: [100, nil]).processed

    blob.purge
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [variant.image.blob])
  end

  test "purge does nothing when attachments exist" do
    create_blob.tap do |blob|
      User.create! name: "DHH", avatar: blob
      assert_no_difference(-> { ActiveStorage::Blob.count }) { blob.purge }
      assert ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purge doesn't raise when blob is not persisted" do
    build_blob_after_unfurling.tap do |blob|
      assert_nothing_raised { blob.purge }
      assert_predicate blob, :destroyed?
    end
  end

  test "uses service from blob when provided" do
    with_service("mirror") do
      blob = create_blob(filename: "funky.jpg", service_name: :local)
      assert_instance_of ActiveStorage::Service::DiskService, blob.service
    end
  end

  test "doesn't create a valid blob if service setting is nil" do
    with_service(nil) do
      assert_raises(ActiveRecord::RecordInvalid) do
        create_blob(filename: "funky.jpg")
      end
    end
  end

  test "invalidates record when provided service_name is invalid" do
    blob = create_blob(filename: "funky.jpg")
    blob.update(service_name: :unknown)

    assert_not blob.valid?
    assert_equal ["is invalid"], blob.errors[:service_name]
  end

  test "updating the content_type updates service metadata" do
    blob = directly_upload_file_blob(filename: "racecar.jpg", content_type: "application/octet-stream")

    assert_called_with(blob.service, :update_metadata, [blob.key], content_type: "image/jpeg", custom_metadata: {}) do
      blob.update!(content_type: "image/jpeg")
    end
  end

  test "updating the metadata updates service metadata" do
    blob = directly_upload_file_blob(filename: "racecar.jpg", content_type: "application/octet-stream")

    expected_arguments = [
      blob.key
    ]

    expected_kwargs = {
      content_type: "application/octet-stream",
      disposition: :attachment,
      filename: blob.filename,
      custom_metadata: { "test" => true }
    }

    assert_called_with(blob.service, :update_metadata, expected_arguments, **expected_kwargs) do
      blob.update!(metadata: { custom: { "test" => true } })
    end
  end

  test "scope_for_strict_loading adds includes only when track_variants and strict_loading_by_default" do
    assert_empty ActiveStorage::Blob.scope_for_strict_loading.includes_values

    with_strict_loading_by_default do
      assert_not_empty ActiveStorage::Blob.scope_for_strict_loading.includes_values

      without_variant_tracking do
        assert_empty ActiveStorage::Blob.scope_for_strict_loading.includes_values
      end
    end
  end

  private
    def expected_url_for(blob, disposition: :attachment, filename: nil, content_type: nil, service_name: :local)
      filename ||= blob.filename
      content_type ||= blob.content_type

      key_params = { key: blob.key, disposition: ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename.sanitized), content_type: content_type, service_name: service_name }

      "https://example.com/rails/active_storage/disk/#{ActiveStorage.verifier.generate(key_params, expires_in: 5.minutes, purpose: :blob_key)}/#{filename}"
    end
end
