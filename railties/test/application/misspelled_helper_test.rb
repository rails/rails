# encoding: utf-8
require 'isolation/abstract_unit'
require 'rack/test'
require 'active_support/json'

module ApplicationTests
  class MisspelledHelperTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    setup do
      build_app
      simple_controller

      app_file 'app/helpers/foo_helper.rb', 'module BarHelper; end'

      boot_rails
    end

    teardown { teardown_app }

    test "loading a misspelled helper returns a helpful error message" do
      e = assert_raise(NameError) { get 'foo/index' }
      assert_equal "Couldn't find FooHelper, expected it to be defined in app/helpers/foo_helper.rb", e.message
    end
  end
end
