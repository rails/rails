# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  tmp_config = { tmp: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") } }
  SERVICE = ActiveStorage::Service.configure(:tmp, tmp_config)

  include ActiveStorage::Service::SharedServiceTests

  test "name" do
    assert_equal :tmp, @service.name
  end

  test "url_for_direct_upload" do
    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)

    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = Digest::MD5.base64digest(data)

    begin
      assert_match(/^https:\/\/example.com\/rails\/active_storage\/disk\/.*$/,
        @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum))
    ensure
      Rails.application.routes.default_url_options = original_url_options
    end
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

  test "URL generation without ActiveStorage::Current.url_options set" do
    ActiveStorage::Current.url_options = nil

    error = assert_raises ArgumentError do
      @service.url(@key, expires_in: 5.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")
    end

    assert_equal("Cannot generate URL for avatar.png using Disk service, please set ActiveStorage::Current.url_options.", error.message)
  end

  test "URL generation keeps working with ActiveStorage::Current.host set" do
    ActiveStorage::Current.url_options = { host: "https://example.com" }

    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)
    begin
      assert_match(/^http:\/\/example.com:3001\/rails\/active_storage\/disk\/.*\/avatar\.png$/,
        @service.url(@key, expires_in: 5.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png"))
    ensure
      Rails.application.routes.default_url_options = original_url_options
    end
  end

  test "headers_for_direct_upload generation" do
    assert_equal({ "Content-Type" => "application/json" }, @service.headers_for_direct_upload(@key, content_type: "application/json"))
  end

  test "root" do
    assert_equal tmp_config.dig(:tmp, :root), @service.root
  end

  test "can change root" do
    tmp_path_2 = File.join(Dir.tmpdir, "active_storage_2")
    @service.root = tmp_path_2

    assert_equal tmp_path_2, @service.root
  ensure
    @service.root = tmp_config.dig(:tmp, :root)
  end
end
