# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/securerandom"
require "active_storage/service/s3_service"

class ActiveStorage::Service::ChecksumImplementationTest < ActiveSupport::TestCase
  setup do
    @previous_checksum_implementation = ActiveStorage.checksum_implementation
    ActiveStorage.checksum_implementation = Digest::MD5
  end

  teardown do
    ActiveStorage.checksum_implementation = @previous_checksum_implementation
  end

  test "disk checksums use Digest::MD5 when OpenSSL MD5 is disabled" do
    service = nil
    file = nil
    service = ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir)
    data = "Hello world!"
    key = SecureRandom.base58(24)
    file = Tempfile.new("checksum")

    with_openssl_md5_disabled do
      assert_equal Digest::MD5.base64digest(data), service.compute_checksum(StringIO.new(data))

      file.binmode
      file.write(data)
      file.rewind
      File.open(file.path, "rb") do |io|
        assert_equal Digest::MD5.base64digest(data), service.compute_checksum(io)
      end

      service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data))
      service.open(key, checksum: Digest::MD5.base64digest(data)) do |downloaded|
        assert_equal data, downloaded.read
      end

      assert_raises ActiveStorage::IntegrityError do
        service.open(key, checksum: Digest::MD5.base64digest("bogus")) { flunk "Expected integrity check to fail" }
      end
    end
  ensure
    file&.close!
    FileUtils.rm_rf(service.root) if service
  end

  test "s3 md5 checksums use Digest::MD5 when OpenSSL MD5 is disabled" do
    service = build_s3_service
    data = "Hello world!"

    with_openssl_md5_disabled do
      assert_equal Digest::MD5, service.checksum_implementation
      assert_equal Digest::MD5, service.default_digest_class
      assert_equal Digest::MD5.base64digest(data), service.compute_checksum(StringIO.new(data))
    end
  end

  test "s3 sha256 checksums stay on OpenSSL SHA256" do
    service = build_s3_service(default_digest_type: :sha256)
    data = "Hello world!"

    assert_equal OpenSSL::Digest::SHA256, service.checksum_implementation
    assert_equal "sha256:#{OpenSSL::Digest::SHA256.base64digest(data)}", service.compute_checksum(StringIO.new(data))
  end

  private
    def with_openssl_md5_disabled(&block)
      raiser = ->(*) { raise OpenSSL::Digest::DigestError, "MD5 disabled" }
      OpenSSL::Digest::MD5.stub(:new, raiser) do
        OpenSSL::Digest::MD5.stub(:file, raiser) do
          OpenSSL::Digest::MD5.stub(:base64digest, raiser, &block)
        end
      end
    end

    def build_s3_service(**options)
      resource = Object.new
      resource.define_singleton_method(:bucket) { |*| nil }
      resource.define_singleton_method(:client) { nil }
      Aws::S3::Resource.stub(:new, resource) do
        Aws::S3::TransferManager.stub(:new, Object.new) do
          ActiveStorage::Service::S3Service.new(bucket: "test", region: "us-east-1", **options)
        end
      end
    end
end
