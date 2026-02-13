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

    test "Rails.app.revision returns nil by default" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"
        assert_nil Rails.app.revision
      end
    end

    test "revision reads from REVISION file when present" do
      File.write("#{app_path}/REVISION", "abc123def456")
      require "#{app_path}/config/environment"
      assert_equal "abc123def456", Rails.app.revision
    end

    test "revision can be set via config.revision string" do
      add_to_config <<-RUBY
        config.revision = "deploy-123"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "deploy-123", Rails.app.revision
    end

    test "config.revision takes precedence over REVISION file" do
      File.write("#{app_path}/REVISION", "file-revision")

      add_to_config <<-RUBY
        config.revision = "config-wins"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "config-wins", Rails.app.revision
    end

    test "revision reads from ENV['REVISION'] when present" do
      ENV["REVISION"] = "env-revision-123"
      require "#{app_path}/config/environment"
      assert_equal "env-revision-123", Rails.app.revision
    ensure
      ENV.delete("REVISION")
    end

    test "ENV['REVISION'] takes precedence over REVISION file" do
      File.write("#{app_path}/REVISION", "file-revision")
      ENV["REVISION"] = "env-wins"

      require "#{app_path}/config/environment"
      assert_equal "env-wins", Rails.app.revision
    ensure
      ENV.delete("REVISION")
    end

    test "config.revision takes precedence over ENV['REVISION']" do
      ENV["REVISION"] = "env-revision"

      add_to_config <<-RUBY
        config.revision = "config-wins"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "config-wins", Rails.app.revision
    ensure
      ENV.delete("REVISION")
    end

    test "Rails::Info includes revision when present" do
      File.write("#{app_path}/REVISION", "deadbeef123")

      require "#{app_path}/config/environment"

      assert_equal "deadbeef123", Rails::Info.properties.value_for("Application revision")
    end

    class ContextReporter
      attr_reader :context

      def report(error, handled:, severity:, context:, source:)
        @context = context
      end
    end

    test "Rails.error includes revision" do
      File.write("#{app_path}/REVISION", "deadbeef123")
      require "#{app_path}/config/environment"
      reporter = ContextReporter.new
      Rails.error.subscribe(reporter)
      Rails.error.handle(context: { some: :context }) { raise }
      assert_equal :context, reporter.context[:some]
      assert_equal({ version: Rails::VERSION::STRING, app_revision: "deadbeef123", environment: "development" }, reporter.context[:rails])
    end
  end
end
