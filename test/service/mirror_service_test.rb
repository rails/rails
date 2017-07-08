require "tmpdir"
require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  PRIMARY_DISK_SERVICE   = ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage"))
  MIRROR_SERVICES = (1..3).map do |i|
    ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage_mirror_#{i}"))
  end

  SERVICE = ActiveStorage::Service.configure :Mirror, primary: PRIMARY_DISK_SERVICE, mirrors: MIRROR_SERVICES

  include ActiveStorage::Service::SharedServiceTests

  test "uploading to all services" do
    begin
      data = "Something else entirely!"
      key  = upload(data, to: @service)

      assert_equal data, PRIMARY_DISK_SERVICE.download(key)
      MIRROR_SERVICES.each do |mirror|
        assert_equal data, mirror.download(key)
      end
    ensure
      @service.delete key
    end
  end

  test "downloading from primary service" do
    data = "Something else entirely!"
    key  = upload(data, to: PRIMARY_DISK_SERVICE)

    assert_equal data, @service.download(key)
  end

  test "deleting from all services" do
    @service.delete FIXTURE_KEY
    assert_not PRIMARY_DISK_SERVICE.exist?(FIXTURE_KEY)
    MIRROR_SERVICES.each do |mirror|
      assert_not mirror.exist?(FIXTURE_KEY)
    end
  end

  test "URL generation in primary service" do
    travel_to Time.now do
      assert_equal PRIMARY_DISK_SERVICE.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt"),
        @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
    end
  end

  private
    def upload(data, to:)
      SecureRandom.base58(24).tap do |key|
        io = StringIO.new(data).tap(&:read)
        @service.upload key, io, checksum: Digest::MD5.base64digest(data)
        assert io.eof?
      end
    end
end
