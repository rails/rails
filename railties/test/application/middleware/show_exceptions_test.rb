require 'isolation/abstract_unit'

module ApplicationTests
  class ShowExceptionsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "unspecified route when set action_dispatch.show_exceptions to false" do
      make_basic_app do |app|
        app.config.action_dispatch.show_exceptions = false
      end

      assert_raise(ActionController::RoutingError) do
        get '/foo'
      end
    end

    test "unspecified route when set action_dispatch.show_exceptions to true" do
      make_basic_app do |app|
        app.config.action_dispatch.show_exceptions = true
      end

      assert_nothing_raised(ActionController::RoutingError) do
        get '/foo'
      end
    end
  end
end
