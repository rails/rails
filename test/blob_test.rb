require "test_helper"
require "database/setup"
require "active_file/blob"

class ActiveFile::BlobTest < ActiveSupport::TestCase
  test "create after upload sets byte size and checksum" do
    data = "Hello world!"
    blob = create_blob data: data

    assert_equal data, blob.download
    assert_equal data.length, blob.byte_size
    assert_equal Digest::MD5.hexdigest(data), blob.checksum
  end

  test "url expiring in 5 minutes" do
    blob = create_blob

    travel_to Time.now do
      assert_equal "/rails/blobs/#{ActiveFile::VerifiedKeyWithExpiration.encode(blob.key, expires_in: 5.minutes)}", blob.url
    end
  end

  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveFile::Blob.create_after_upload! data: StringIO.new(data), filename: filename, content_type: content_type
    end
end
