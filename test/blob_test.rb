require "test_helper"
require "database/setup"
require "active_storage/blob"

class ActiveStorage::BlobTest < ActiveSupport::TestCase
  test "create after upload sets byte size and checksum" do
    data = "Hello world!"
    blob = create_blob data: data

    assert_equal data, blob.download
    assert_equal data.length, blob.byte_size
    assert_equal Digest::MD5.base64digest(data), blob.checksum
  end

  test "urls expiring in 5 minutes" do
    blob = create_blob

    travel_to Time.now do
      assert_equal expected_url_for(blob), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment), blob.url(disposition: :attachment)
    end
  end

  private
    def expected_url_for(blob, disposition: :inline)
      "/rails/active_storage/disk/#{ActiveStorage::VerifiedKeyWithExpiration.encode(blob.key, expires_in: 5.minutes)}/#{blob.filename}?disposition=#{disposition}"
    end
end
