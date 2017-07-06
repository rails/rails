require "tmpdir"
require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  PRIMARY_DISK_SERVICE   = ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage"))
  SECONDARY_DISK_SERVICE = ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage_mirror"))

  SERVICE = ActiveStorage::Service.configure :Mirror, services: [ PRIMARY_DISK_SERVICE, SECONDARY_DISK_SERVICE ]

  include ActiveStorage::Service::SharedServiceTests

  test "uploading to all services" do
    begin
      data = "Something else entirely!"
      key  = upload(data, to: @service)

      assert_equal data, PRIMARY_DISK_SERVICE.download(key)
      assert_equal data, SECONDARY_DISK_SERVICE.download(key)
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
    assert_not SECONDARY_DISK_SERVICE.exist?(FIXTURE_KEY)
  end

  test "URL generation in primary service" do
    travel_to Time.now do
      assert_equal PRIMARY_DISK_SERVICE.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt"),
        @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
    end
  end

  def upload(data, to:)
    SecureRandom.base58(24).tap do |key|
      @service.upload key, StringIO.new(data)
    end
  end
end
