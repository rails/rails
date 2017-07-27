require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service::DiskService.new(root: File.join(Dir.tmpdir, "active_storage"))

  include ActiveStorage::Service::SharedServiceTests

  test "url generation" do
    assert_match /rails\/active_storage\/disk\/.*\/avatar\.png\?.+disposition=inline/,
      @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: "avatar.png", content_type: "image/png")
  end
end
