require "isolation/abstract_unit"
# require "rails"
# require 'action_dispatch'

module ApplicationTests
  class LoadTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def rackup
      config = "#{app_path}/config.ru"
      # Copied from ActionDispatch::Utils.parse_config
      # ActionDispatch is not necessarily available at this point.
      require 'rack'
      if config =~ /\.ru$/
        cfgfile = ::File.read(config)
        if cfgfile[/^#\\(.*)/]
          opts.parse! $1.split(/\s+/)
        end
        inner_app = eval "Rack::Builder.new {( " + cfgfile + "\n )}.to_app",
                         nil, config
      else
        require config
        inner_app = Object.const_get(::File.basename(config, '.rb').capitalize)
      end
    end

    def setup
      build_app
      boot_rails
    end

    test "rails app is present" do
      assert File.exist?(app_path("config"))
    end

    test "config.ru can be racked up" do
      @app = rackup
      assert_welcome get("/")
    end

    test "Rails.application is available after config.ru has been racked up" do
      rackup
      assert Rails.application < Rails::Application
    end

    # Passenger still uses AC::Dispatcher, so we need to
    # keep it working for now
    test "deprecated ActionController::Dispatcher still works" do
      rackup
      assert ActionController::Dispatcher.new < Rails::Application
    end

    test "the config object is available on the application object" do
      rackup
      assert_equal 'UTC', Rails.application.config.time_zone
    end
  end
end
