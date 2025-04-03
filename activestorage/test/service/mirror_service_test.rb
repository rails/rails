# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  mirror_config = (1..3).to_h do |i|
    [ "mirror_#{i}",
      service: "Disk",
      root: Dir.mktmpdir("active_storage_tests_mirror_#{i}") ]
  end

  config = mirror_config.merge \
    mirror:  { service: "Mirror", primary: "primary", mirrors: mirror_config.keys },
    primary: { service: "Disk", root: Dir.mktmpdir("active_storage_tests_primary") }

  SERVICE = ActiveStorage::Service.configure :mirror, config

  include ActiveStorage::Service::SharedServiceTests
  include ActiveJob::TestHelper

  test "name" do
    assert_equal :mirror, @service.name
  end

  test "uploading to all services" do
    old_service = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = @service

    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    io       = StringIO.new(data)
    checksum = ActiveStorage.checksum_implementation.base64digest(data)

    assert_performed_jobs 1, only: ActiveStorage::MirrorJob do
      @service.upload key, io.tap(&:read), checksum: checksum
    end

    assert_predicate io, :eof?

    assert_equal data, @service.primary.download(key)
    @service.mirrors.each do |mirror|
      assert_equal data, mirror.download(key)
    end
  ensure
    @service.delete key
    ActiveStorage::Blob.service = old_service
  end

  test "downloading from primary service" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = ActiveStorage.checksum_implementation.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum

    assert_equal data, @service.download(key)
  end

  test "deleting from all services" do
    @service.delete @key

    assert_not SERVICE.primary.exist?(@key)
    SERVICE.mirrors.each do |mirror|
      assert_not mirror.exist?(@key)
    end
  end

  test "mirroring a file from the primary service to secondary services where it doesn't exist" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = ActiveStorage.checksum_implementation.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum
    @service.mirrors.third.upload key, StringIO.new("Surprise!")

    @service.mirror key, checksum: checksum
    assert_equal data, @service.mirrors.first.download(key)
    assert_equal data, @service.mirrors.second.download(key)
    assert_equal "Surprise!", @service.mirrors.third.download(key)
  end

  test "URL generation in primary service" do
    filename = ActiveStorage::Filename.new("test.txt")

    freeze_time do
      assert_equal @service.primary.url(@key, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain"),
        @service.url(@key, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain")
    end
  end

  test "path for file in primary service" do
    assert_equal @service.primary.path_for(@key), @service.path_for(@key)
  end
end
