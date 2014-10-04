require "isolation/abstract_unit"
require 'rack/test'
require 'env_helpers'

module ApplicationTests
  class ValidateEnvironmentVarsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(initializers: true)
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "env variable must exist" do
      ENV['FOO_API_KEY'] = '123456' # That's the combination on my luggage

      add_to_env_config "development", "config.required_env_vars = ['FOO_API_KEY']"

      assert_nothing_raised do
        require "#{app_path}/config/environment"
        app.send("validate_environment_vars!")
      end
    end

    def test_env_variable_non_existent
      ENV['FOO_API_KEY'] = 'xyz123'

      add_to_env_config "development", "config.required_env_vars = ['Foo_API_KEY1', 'FOO_API_KEY2', :FOO_API_KEY3, 'FOO_API_KEY3']"

      error = assert_raises RuntimeError do
        require "#{app_path}/config/environment"
        app.send("validate_environment_vars!")
      end

      assert_match /Foo_API_KEY1, FOO_API_KEY2, FOO_API_KEY3/, error.message
    end

    def test_env_variable_as_string
      ENV['FOO_API_KEY'] = 'xyz123'

      add_to_env_config "development", "config.required_env_vars = 'FOO_API_KEY'"

      assert_nothing_raised do
        require "#{app_path}/config/environment"
        app.send("validate_environment_vars!")
      end
    end
  end
end
