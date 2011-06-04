require "isolation/abstract_unit"

module ApplicationTests
  class RackupTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def rackup
      require "rack"
      app, options = Rack::Builder.parse_file("#{app_path}/config.ru")
      app
    end

    def setup
      @prev_rails_env = ENV['RAILS_ENV']
      ENV['RAILS_ENV'] = 'development'
      build_app
      boot_rails
    end

    def teardown
      ENV['RAILS_ENV'] = @prev_rails_env
    end

    test "rails app is present" do
      assert File.exist?(app_path("config"))
    end

    test "config.ru can be racked up" do
      Dir.chdir app_path do
        @app = rackup
        assert_welcome get("/")
      end
    end

    test "Rails.application is available after config.ru has been racked up" do
      rackup
      assert_kind_of Rails::Application, Rails.application
    end

    test "the config object is available on the application object" do
      rackup
      assert_equal 'UTC', Rails.application.config.time_zone
    end
  end
end
