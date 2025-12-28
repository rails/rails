# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class AppVersionTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "application has version method" do
      require "#{app_path}/config/environment"
      assert_respond_to Rails.application, :version
      assert_kind_of Rails::AppVersion::Version, Rails.application.version
    end

    test "application has app_environment method" do
      require "#{app_path}/config/environment"
      assert_respond_to Rails.application, :app_environment
      assert_kind_of ActiveSupport::StringInquirer, Rails.application.app_environment
    end

    test "version defaults to 0.0.0 when no VERSION file exists" do
      require "#{app_path}/config/environment"
      assert_equal "0.0.0", Rails.application.version.to_s
    end

    test "version reads from VERSION file when present" do
      File.write("#{app_path}/VERSION", "1.2.3")
      require "#{app_path}/config/environment"
      assert_equal "1.2.3", Rails.application.version.to_s
    end

    test "version handles pre-release versions" do
      File.write("#{app_path}/VERSION", "2.0.0-beta.1")
      require "#{app_path}/config/environment"
      assert_equal "2.0.0-beta.1", Rails.application.version.to_s
      assert Rails.application.version.prerelease?
      assert_not Rails.application.version.production_ready?
    end

    test "revision reads from REVISION file when present" do
      File.write("#{app_path}/VERSION", "1.0.0")
      File.write("#{app_path}/REVISION", "abc123def456")
      require "#{app_path}/config/environment"
      assert_equal "abc123de", Rails.application.version.short_revision
      assert_equal "1.0.0 (abc123de)", Rails.application.version.full
    end

    test "app_environment defaults to Rails.env" do
      require "#{app_path}/config/environment"
      assert_equal Rails.env.to_s, Rails.application.app_environment.to_s
    end

    test "app_environment reads from RAILS_APP_ENV when set" do
      ENV["RAILS_APP_ENV"] = "custom_env"
      require "#{app_path}/config/environment"
      assert_equal "custom_env", Rails.application.app_environment.to_s
    ensure
      ENV.delete("RAILS_APP_ENV")
    end

    test "version configuration is available" do
      require "#{app_path}/config/environment"
      assert Rails.application.config.app_version
      assert Rails.application.config.app_version.enabled
      assert Rails.application.config.app_version.add_headers
    end

    test "AppInfo middleware adds headers when enabled" do
      add_to_config <<-RUBY
        config.app_version.enabled = true
        config.app_version.add_headers = true
      RUBY

      File.write("#{app_path}/VERSION", "1.5.0")

      require "#{app_path}/config/environment"

      get "/"
      assert response.headers["X-App-Version"]
      assert response.headers["X-App-Environment"]
    end

    test "health check includes version info when enabled" do
      add_to_config <<-RUBY
        config.app_version.enabled = true
      RUBY

      File.write("#{app_path}/VERSION", "2.0.0")

      require "#{app_path}/config/environment"

      get "/up", headers: { "Accept" => "application/json" }
      json_response = JSON.parse(response.body)

      assert_equal "up", json_response["status"]
      assert_equal "2.0.0", json_response["version"]
      assert json_response["environment"]
      assert json_response["timestamp"]
    end

    test "Rails::Info includes version information" do
      File.write("#{app_path}/VERSION", "3.0.0")
      File.write("#{app_path}/REVISION", "deadbeef123456")

      require "#{app_path}/config/environment"

      properties = Rails::Info.properties

      assert properties.value_for("Application version")
      assert_equal "3.0.0", properties.value_for("Application version")
      assert_equal "deadbeef", properties.value_for("Application revision")
    end

    test "version cache key generation" do
      File.write("#{app_path}/VERSION", "1.2.3-alpha")
      require "#{app_path}/config/environment"

      assert_equal "1-2-3-alpha", Rails.application.version.to_cache_key
    end

    test "production_ready? returns true for stable versions" do
      File.write("#{app_path}/VERSION", "1.0.0")
      require "#{app_path}/config/environment"

      assert Rails.application.version.production_ready?
    end

    test "production_ready? returns false for pre-1.0 versions" do
      File.write("#{app_path}/VERSION", "0.9.0")
      require "#{app_path}/config/environment"

      assert_not Rails.application.version.production_ready?
    end
  end
end
