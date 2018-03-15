# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service::DiskService.new(root: File.join(Dir.tmpdir, "active_storage"))

  include ActiveStorage::Service::SharedServiceTests

  test "url generation" do
    assert_match(Regexp.new("#{Regexp.escape(ActiveStorage.mount_path)}/disk/.*/avatar\\.png\\?content_type=image%2Fpng&disposition=inline"),
      @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png"))
  end
end
