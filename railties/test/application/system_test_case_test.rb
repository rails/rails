# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

class SystemTestCaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test "url helpers are delegated to a proxy class" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index', as: 'test_foo'
      end
    RUBY

    app("test")

    assert_not_includes(ActionDispatch::SystemTestCase.runnable_methods, :test_foo_url)
  end

  test "system tests use 127.0.0.1 in the url_options be default" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index', as: 'test_foo'
      end
    RUBY

    app("test")
    rack_test_case = Class.new(ActionDispatch::SystemTestCase) do
      driven_by :rack_test
    end
    system_test = rack_test_case.new("my_test")
    assert_equal("http://127.0.0.1/foo", system_test.test_foo_url)
  end

  test "system tests use Capybara.app_host in the url_options if present" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index', as: 'test_foo'
      end
    RUBY

    app("test")
    system_test = ActionDispatch::SystemTestCase.new("my_test")
    previous_app_host = ::Capybara.app_host
    ::Capybara.app_host = "https://my_test_example.com"

    assert_equal("https://my_test_example.com/foo", system_test.test_foo_url)
  ensure
    ::Capybara.app_host = previous_app_host
  end
end
