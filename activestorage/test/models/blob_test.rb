# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::BlobTest < ActiveSupport::TestCase
  test "create after upload sets byte size and checksum" do
    data = "Hello world!"
    blob = create_blob data: data

    assert_equal data, blob.download
    assert_equal data.length, blob.byte_size
    assert_equal Digest::MD5.base64digest(data), blob.checksum
  end

  test "create after upload extracts content type from data" do
    blob = create_file_blob content_type: "application/octet-stream"
    assert_equal "image/jpeg", blob.content_type
  end

  test "create after upload extracts content type from filename" do
    blob = create_blob content_type: "application/octet-stream"
    assert_equal "text/plain", blob.content_type
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
    blob   = create_blob data: "a" * 75.kilobytes
    chunks = []

    blob.download do |chunk|
      chunks << chunk
    end

    assert_equal 2, chunks.size
    assert_equal "a" * 64.kilobytes, chunks.first
    assert_equal "a" * 11.kilobytes, chunks.second
  end

  test "urls expiring in 5 minutes" do
    blob = create_blob

    freeze_time do
      assert_equal expected_url_for(blob), blob.service_url
      assert_equal expected_url_for(blob, disposition: :attachment), blob.service_url(disposition: :attachment)
    end
  end

  test "urls force attachment as content disposition for content types served as binary" do
    blob = create_blob(content_type: "text/html")

    freeze_time do
      assert_equal expected_url_for(blob, disposition: :attachment), blob.service_url
      assert_equal expected_url_for(blob, disposition: :attachment), blob.service_url(disposition: :inline)
    end
  end

  test "urls allow for custom filename" do
    blob = create_blob(filename: "original.txt")
    new_filename = ActiveStorage::Filename.new("new.txt")

    freeze_time do
      assert_equal expected_url_for(blob), blob.service_url
      assert_equal expected_url_for(blob, filename: new_filename), blob.service_url(filename: new_filename)
    end
  end

  test "purge deletes file from external service" do
    blob = create_blob

    blob.purge
    assert_not ActiveStorage::Blob.service.exist?(blob.key)
  end

  test "purge deletes variants from external service" do
    blob = create_file_blob
    variant = blob.variant(resize: "100>").processed

    blob.purge
    assert_not ActiveStorage::Blob.service.exist?(variant.key)
  end

  private
    def expected_url_for(blob, disposition: :inline, filename: nil)
      filename ||= blob.filename
      query_string = { content_type: blob.content_type, disposition: "#{disposition}; #{filename.parameters}" }.to_param
      "http://localhost:3000/rails/active_storage/disk/#{ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key)}/#{filename}?#{query_string}"
    end
end
