# frozen_string_literal: true

require "service/shared_service_tests"

module ActiveStorage::Service::SharedDiskServiceTests
  extend ActiveSupport::Concern

  included do
    include ActiveStorage::Service::SharedServiceTests

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
  end
end

class ActiveStorage::Service::DiskServiceTest < ActiveSupport::TestCase
  include ActiveStorage::Service::SharedDiskServiceTests

  tmp_config = { tmp: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") } }
  SERVICE = ActiveStorage::Service.configure(:tmp, tmp_config)

  test "name" do
    assert_equal :tmp, @service.name
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

class ActiveStorage::Service::DiskServiceEnvTest < ActiveSupport::TestCase
  include ActiveStorage::Service::SharedDiskServiceTests

  tmp_config = { tmp: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage") } }
  SERVICE = ActiveStorage::Service.configure(:tmp, tmp_config)

  setup do
    @tmp_dir = File.join(Dir.tmpdir, "active_storage")
    @before_env_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "disk://#{@tmp_dir}"
    @service = ActiveStorage::Service.configure(:env, {})
  end

  teardown do
    ENV["STORAGE_URL"] = @before_env_storage_url
  end

  test "name" do
    assert_equal :env, @service.name
  end

  test "root" do
    assert_equal @tmp_dir, @service.root
  end

  test "can change root" do
    tmp_path_2 = File.join(Dir.tmpdir, "active_storage_2")
    @service.root = tmp_path_2

    assert_equal tmp_path_2, @service.root
  ensure
    @service.root = @tmp_dir
  end
end

class ActiveStorage::Service::DiskServiceOptionsTest < ActiveSupport::TestCase
  test "root path" do
    uri = URI.parse("disk://tmp/storage")
    url = ActiveStorage::Service::UrlConfig.new(uri)
    options = ActiveStorage::Service::DiskService.options_from_url(url)
    assert_equal "tmp/storage", options[:root]

    uri = URI.parse("disk:///root/storage")
    url = ActiveStorage::Service::UrlConfig.new(uri)
    options = ActiveStorage::Service::DiskService.options_from_url(url)
    assert_equal "/root/storage", options[:root]

    uri = URI.parse("disk://storage?splat=true")
    url = ActiveStorage::Service::UrlConfig.new(uri)
    options = ActiveStorage::Service::DiskService.options_from_url(url)
    assert_equal "storage", options[:root]
    assert_equal "true", options[:splat]
  end
end
