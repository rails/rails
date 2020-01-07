# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  tmp_config = { tmp: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") } }
  SERVICE = ActiveStorage::Service.configure(:tmp, tmp_config)

  include ActiveStorage::Service::SharedServiceTests

  test "name" do
    assert_equal :tmp, @service.name
  end

  test "URL generation" do
    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)
    begin
      assert_match(/^https:\/\/example.com\/rails\/active_storage\/disk\/.*\/avatar\.png$/,
        @service.url(@key, expires_in: 5.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png"))
    ensure
      Rails.application.routes.default_url_options = original_url_options
    end
  end

  test "headers_for_direct_upload generation" do
    assert_equal({ "Content-Type" => "application/json" }, @service.headers_for_direct_upload(@key, content_type: "application/json"))
  end
end
