# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

class ActiveStorage::Service::DiskPublicServiceTest < ActiveSupport::TestCase
  tmp_config = {
    tmp_public: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage_public"), public: true }
  }
  SERVICE = ActiveStorage::Service.configure(:tmp_public, tmp_config)

  include ActiveStorage::Service::SharedServiceTests

  test "public URL generation" do
    url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

    assert_match(/^https:\/\/example.com\/rails\/active_storage\/disk\/public\/#{@key}/, url)
  end
end
