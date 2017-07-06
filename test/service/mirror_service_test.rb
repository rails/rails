require "tmpdir"
require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  PRIMARY_DISK_SERVICE   = ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage"))
  SECONDARY_DISK_SERVICE = ActiveStorage::Service.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage_mirror"))

  SERVICE = ActiveStorage::Service.configure :Mirror, services: [ PRIMARY_DISK_SERVICE, SECONDARY_DISK_SERVICE ]

  include ActiveStorage::Service::SharedServiceTests

  test "uploading was done to all services" do
    begin
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"
      io   = StringIO.new(data)
      @service.upload(key, io)

      assert_equal data, PRIMARY_DISK_SERVICE.download(key)
      assert_equal data, SECONDARY_DISK_SERVICE.download(key)
    ensure
      @service.delete key
    end
  end

  test "existing in all services" do
    assert PRIMARY_DISK_SERVICE.exist?(FIXTURE_KEY)
    assert SECONDARY_DISK_SERVICE.exist?(FIXTURE_KEY)
  end
end
