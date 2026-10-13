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

  test "path_for raises InvalidKeyError for basic traversal" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("../../etc/cron.d/evil")
    end
  end

  test "path_for raises InvalidKeyError for deep traversal" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("../../../../../etc/shadow")
    end
  end

  test "path_for raises InvalidKeyError for sibling directory bypass" do
    original_root = @service.root
    @service.root = File.join(Dir.tmpdir, "active_store")
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("../../../../tmp/store_backup/secret")
    end
  ensure
    @service.root = original_root
  end

  test "path_for raises InvalidKeyError for null byte injection" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("validkey\x00.jpg")
    end
  end

  test "path_for raises InvalidKeyError for null byte with traversal" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("../../etc/passwd\x00.jpg")
    end
  end

  test "path_for raises InvalidKeyError for empty key" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("")
    end

    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for(nil)
    end
  end

  test "path_for raises InvalidKeyError for single dot segment" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("avatars/./123")
    end
  end

  test "path_for raises InvalidKeyError for double dot mid-path" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("avatars/../users/123")
    end
  end

  test "path_for raises InvalidKeyError for key whose folder_for output escapes root" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("....payload")
    end
  end

  test "path_for raises InvalidKeyError for short key whose folder_for output escapes root" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("..something")
    end
  end

  test "path_for raises InvalidKeyError for non-ASCII-compatible encoded key" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.path_for("abc".encode("UTF-16LE"))
    end
  end

  test "path_for returns path within root for alternate secure random key" do
    key = SecureRandom.base58(24)
    path = @service.path_for(key)
    assert path.start_with?(File.expand_path(@service.root) + "/")
  end

  test "path_for returns path within root for a slash-containing key" do
    path = @service.path_for("avatars/123/photo")
    assert path.start_with?(File.expand_path(@service.root) + "/")
  end

  test "delete_prefixed raises InvalidKeyError for traversal prefix" do
    assert_raises ActiveStorage::InvalidKeyError do
      @service.delete_prefixed("../../etc/cron.d/")
    end
  end

  test "path_for escapes all glob metacharacters" do
    assert_equal "\\[", @service.send(:escape_glob_metacharacters, "[")
    assert_equal "\\]", @service.send(:escape_glob_metacharacters, "]")
    assert_equal "\\*", @service.send(:escape_glob_metacharacters, "*")
    assert_equal "\\?", @service.send(:escape_glob_metacharacters, "?")
    assert_equal "\\{", @service.send(:escape_glob_metacharacters, "{")
    assert_equal "\\}", @service.send(:escape_glob_metacharacters, "}")
    assert_equal "\\\\", @service.send(:escape_glob_metacharacters, "\\")
    assert_equal "hello", @service.send(:escape_glob_metacharacters, "hello")
    assert_equal "/path/to/\\[brackets\\]/file", @service.send(:escape_glob_metacharacters, "/path/to/[brackets]/file")
  end

  test "delete_prefixed with glob metacharacters only deletes matching files" do
    base_key = SecureRandom.base58(24)
    bracket_key = "#{base_key}[1]/file"
    plain_key = "#{base_key}1/file"

    @service.upload(bracket_key, StringIO.new("bracket"))
    @service.upload(plain_key, StringIO.new("plain"))

    @service.delete_prefixed("#{base_key}[1]/")

    assert @service.exist?(plain_key), "file should not be deleted"
    assert_not @service.exist?(bracket_key), "file should be deleted"
  ensure
    @service.delete(bracket_key) rescue nil
    @service.delete(plain_key) rescue nil
  end

  test "delete_prefixed with trailing slash only deletes files inside the directory" do
    base_key = SecureRandom.base58(24)
    inside_key = "#{base_key}/file"
    sibling_key = "#{base_key}_sibling"

    @service.upload(inside_key, StringIO.new("inside"))
    @service.upload(sibling_key, StringIO.new("sibling"))

    @service.delete_prefixed("#{base_key}/")

    assert @service.exist?(sibling_key), "sibling file should not be deleted"
    assert_not @service.exist?(inside_key), "file inside directory should be deleted"
  ensure
    @service.delete(inside_key) rescue nil
    @service.delete(sibling_key) rescue nil
  end

  test "can change root" do
    tmp_path_2 = File.join(Dir.tmpdir, "active_storage_2")
    @service.root = tmp_path_2

    assert_equal tmp_path_2, @service.root
  ensure
    @service.root = tmp_config.dig(:tmp, :root)
  end
end
