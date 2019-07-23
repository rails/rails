# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service::DiskService.new(root: File.join(Dir.tmpdir, "active_storage"))

  include ActiveStorage::Service::SharedServiceTests

  test "URL generation" do
    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)
    begin
      assert_match(/^https:\/\/example.com\/rails\/active_storage\/disk\/.*\/avatar\.png\?content_type=image%2Fpng&disposition=inline/,
        @service.url(@key, expires_in: 5.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png"))
    ensure
      Rails.application.routes.default_url_options = original_url_options
    end
  end
end
