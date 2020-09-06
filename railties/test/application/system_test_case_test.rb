# frozen_string_literal: true

require 'isolation/abstract_unit'
require 'rack/test'

class SystemTestCaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test 'url helpers are delegated to a proxy class' do
    app_file 'config/routes.rb', <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index', as: 'test_foo'
      end
    RUBY

    app('test')

    assert_not_includes(ActionDispatch::SystemTestCase.runnable_methods, :test_foo_url)
  end

  test 'system tests set the Capybara host in the url_options by default' do
    app_file 'config/routes.rb', <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index', as: 'test_foo'
      end
    RUBY

    app('test')
    system_test = ActionDispatch::SystemTestCase.new('my_test')
    previous_app_host = ::Capybara.app_host
    ::Capybara.app_host = 'https://my_test_example.com'

    assert_equal('https://my_test_example.com/foo', system_test.test_foo_url)
  ensure
    ::Capybara.app_host = previous_app_host
  end
end
