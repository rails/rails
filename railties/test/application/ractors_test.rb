# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_support/testing/ractors_assertions"

if RUBY_VERSION >= "4.0"
  module ApplicationTests
    class RactorsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation
      include ActiveSupport::Testing::RactorsAssertions

      def setup
        build_app

        add_to_env_config "production", "ActiveSupport::Ractors.unshareable_proc_action = :raise"

        # Remove defaults that are not compatible
        add_to_env_config "production", "config.logger = ActiveSupport::Ractors::Logger.new"
        add_to_env_config "production", "config.public_file_server.enabled = false" # Requires release of https://github.com/rack/rack/pull/2469
        add_to_env_config "production", "config.cache_store = :null_store"
        add_to_env_config "production", "config.action_cable.mount_path = nil"
      end

      def teardown
        teardown_app
      end

      test "ractorize! makes the app shareable in production mode" do
        app "production"

        begin
          @original_experimental_warning = Warning[:experimental]
          Warning[:experimental] = false
          Rails.application.ractorize!
        ensure
          Warning[:experimental] = @original_experimental_warning
        end

        assert_ractor_shareable Rails.application
        assert_ractor_shareable Rails.event
        assert_ractor_shareable Rails.error
        assert_ractor_shareable Rails.backtrace_cleaner
      end
    end
  end
end
