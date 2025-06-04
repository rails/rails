# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "rails-dom-testing"

module ApplicationTests
  class DirectUploadsIntegrationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include Rails::Dom::Testing::Assertions

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_creating_new_upload
      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      file = file_fixture("racecar.jpg")
      checksum = OpenSSL::Digest::MD5.new(file.read).base64digest
      key = SecureRandom.base58(24)

      file_data = {
        key: key,
        filename: file.basename.to_s,
        content_type: "image/jpeg",
        byte_size: file.size,
        checksum: checksum
      }

      post("/rails/active_storage/direct_uploads",
           { blob: file_data }.to_json,
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 200, last_response.status

      response_data = JSON.parse(last_response.body)

      assert_equal "image/jpeg", response_data["content_type"]
      assert_equal checksum, response_data["checksum"]
      assert_equal file.size, response_data["byte_size"]
      assert_equal file.basename.to_s, response_data["filename"]
      assert_equal "local", response_data["service_name"]
    end

    def test_creating_new_upload_with_forgery_protection_enabled
      add_to_config "config.action_controller.allow_forgery_protection = true"
      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      file = file_fixture("racecar.jpg")
      checksum = OpenSSL::Digest::MD5.new(file.read).base64digest
      key = SecureRandom.base58(24)

      file_data = {
        key: key,
        filename: file.basename.to_s,
        content_type: "image/jpeg",
        byte_size: file.size,
        checksum: checksum
      }

      post("/rails/active_storage/direct_uploads",
           { blob: file_data }.to_json,
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 422, last_response.status
    end

    def test_api_only
      add_to_config "config.api_only = true"
      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      file = file_fixture("racecar.jpg")
      checksum = OpenSSL::Digest::MD5.new(file.read).base64digest
      key = SecureRandom.base58(24)

      file_data = {
        key: key,
        filename: file.basename.to_s,
        content_type: "image/jpeg",
        byte_size: file.size,
        checksum: checksum
      }

      post("/rails/active_storage/direct_uploads",
           { blob: file_data }.to_json,
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 200, last_response.status
      response_data = JSON.parse(last_response.body)

      assert_equal "image/jpeg", response_data["content_type"]
      assert_equal checksum, response_data["checksum"]
      assert_equal file.size, response_data["byte_size"]
      assert_equal file.basename.to_s, response_data["filename"]
      assert_equal "local", response_data["service_name"]
    end

    def test_etag_with_template_digest
      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      file = file_fixture("racecar.jpg")
      checksum = OpenSSL::Digest::MD5.new(file.read).base64digest
      key = SecureRandom.base58(24)

      file_data = {
        key: key,
        filename: file.basename.to_s,
        content_type: "image/jpeg",
        byte_size: file.size,
        checksum: checksum
      }

      post("/rails/active_storage/direct_uploads",
           { blob: file_data }.to_json,
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 200, last_response.status

      response_data = JSON.parse(last_response.body)

      assert_equal "image/jpeg", response_data["content_type"]
      assert_equal checksum, response_data["checksum"]
      assert_equal file.size, response_data["byte_size"]
      assert_equal file.basename.to_s, response_data["filename"]
      assert_equal "local", response_data["service_name"]

      expected_etag = generate_etag(last_response.body)
      assert_equal expected_etag, last_response.headers["ETag"]
    end

    def test_api_only_with_custom_session
      remove_from_config "config.action_controller.allow_forgery_protection = false"
      add_to_config "config.api_only = true"
      add_to_config "config.active_storage.base_controller_parent = \"::ActionController::Base\""
      add_to_config "config.session_store :cookie_store, key: '_myapp_session'"
      add_to_config "config.middleware.use config.session_store, config.session_options"

      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      file = file_fixture("racecar.jpg")
      checksum = OpenSSL::Digest::MD5.new(file.read).base64digest
      key = SecureRandom.base58(24)

      file_data = {
        key: key,
        filename: file.basename.to_s,
        content_type: "image/jpeg",
        byte_size: file.size,
        checksum: checksum
      }

      post("/rails/active_storage/direct_uploads",
           { blob: file_data }.to_json,
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 422, last_response.status
    end

    private
      def generate_etag(body)
        "W/\"#{ActiveSupport::Digest.hexdigest(body)}\""
      end
  end
end
