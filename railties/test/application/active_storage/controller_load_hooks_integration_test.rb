# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ControllerLoadHooksIntegrationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    self.file_fixture_path = "test/fixtures/files"

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_initializer_can_authorize_direct_uploads_through_the_load_hook
      app_file "config/initializers/active_storage_authorization.rb", <<~RUBY
        ActiveSupport.on_load(:active_storage_direct_uploads_controller) do
          before_action { head :forbidden unless request.headers["X-Api-Token"] == "secret" }
        end
      RUBY

      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      post "/rails/active_storage/direct_uploads", direct_upload_params.to_json,
        "CONTENT_TYPE" => "application/json"
      assert_equal 403, last_response.status

      post "/rails/active_storage/direct_uploads", direct_upload_params.to_json,
        "CONTENT_TYPE" => "application/json", "HTTP_X_API_TOKEN" => "secret"
      assert_equal 200, last_response.status
    end

    def test_initializer_can_disable_the_public_cache_through_the_load_hook
      app_file "config/initializers/active_storage_authorization.rb", <<~RUBY
        ActiveSupport.on_load(:active_storage_blobs_proxy_controller) do
          self.public_cache = false
        end
      RUBY

      rails "active_storage:install"
      rails "db:migrate"

      app("development")

      blob = ActiveStorage::Blob.create_and_upload!(
        io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg"
      )

      get "/rails/active_storage/blobs/proxy/#{blob.signed_id}/#{blob.filename}"
      assert_equal 200, last_response.status
      assert_includes last_response.headers["Cache-Control"], "private"
    end

    private
      def direct_upload_params
        file = file_fixture("racecar.jpg")

        { blob: {
          key: SecureRandom.base58(24),
          filename: file.basename.to_s,
          content_type: "image/jpeg",
          byte_size: file.size,
          checksum: OpenSSL::Digest::MD5.new(file.read).base64digest
        } }
      end
  end
end
