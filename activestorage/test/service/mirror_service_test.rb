# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  mirror_config = (1..3).map do |i|
    [ "mirror_#{i}",
      service: "Disk",
      root: Dir.mktmpdir("active_storage_tests_mirror_#{i}") ]
  end.to_h

  config = mirror_config.merge \
    mirror:  { service: "Mirror", primary: "primary", mirrors: mirror_config.keys },
    primary: { service: "Disk", root: Dir.mktmpdir("active_storage_tests_primary") }

  SERVICE = ActiveStorage::Service.configure :mirror, config

  include ActiveStorage::Service::SharedServiceTests

  test "uploading to all services" do
    begin
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      io       = StringIO.new(data)
      checksum = Digest::MD5.base64digest(data)

      @service.upload key, io.tap(&:read), checksum: checksum
      assert_predicate io, :eof?

      assert_equal data, @service.primary.download(key)
      @service.mirrors.each do |mirror|
        assert_equal data, mirror.download(key)
      end
    ensure
      @service.delete key
    end
  end

  test "downloading from primary service" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = Digest::MD5.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum

    assert_equal data, @service.download(key)
  end

  test "deleting from all services" do
    @service.delete FIXTURE_KEY

    assert_not SERVICE.primary.exist?(FIXTURE_KEY)
    SERVICE.mirrors.each do |mirror|
      assert_not mirror.exist?(FIXTURE_KEY)
    end
  end

  test "URL generation in primary service" do
    filename = ActiveStorage::Filename.new("test.txt")

    freeze_time do
      assert_equal @service.primary.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain"),
        @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain")
    end
  end
end
