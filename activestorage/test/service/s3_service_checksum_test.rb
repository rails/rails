# frozen_string_literal: true

require "test_helper"
require "active_storage/service/s3_service"

class ActiveStorage::Service::S3ServiceChecksumTest < ActiveSupport::TestCase
  def build_service(**options)
    ActiveStorage::Service::S3Service.new(
      bucket: "test-bucket",
      region: "us-east-1",
      access_key_id: "test",
      secret_access_key: "test",
      **options
    )
  end

  test "sha256 SDK upload params carry the bare digest, not the algorithm-prefixed value" do
    service = build_service(default_digest_type: :sha256)

    # For non-MD5 digest types, compute_checksum prefixes the digest with "type:".
    params = service.send(:s3_sdk_upload_params, "sha256:Zm9vYmFy")

    assert_equal :sha256, params[:checksum_algorithm]
    assert_equal "Zm9vYmFy", params[:checksum_sha256]
  end

  test "md5 SDK upload params pass the digest through as content_md5" do
    service = build_service(default_digest_type: :md5)

    assert_equal({ content_md5: "Zm9vYmFy" }, service.send(:s3_sdk_upload_params, "Zm9vYmFy"))
  end
end
