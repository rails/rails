require 'isolation/abstract_unit'

module ApplicationTests
  class CookiesTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def new_app
      File.expand_path("#{app_path}/../new_app")
    end

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
    end

    def teardown
      teardown_app
      FileUtils.rm_rf(new_app) if File.directory?(new_app)
    end

    test 'always_write_cookie is true by default in development' do
      require 'rails'
      Rails.env = 'development'
      require "#{app_path}/config/environment"
      assert_equal true, ActionDispatch::Cookies::CookieJar.always_write_cookie
    end

    test 'always_write_cookie is false by default in production' do
      require 'rails'
      Rails.env = 'production'
      require "#{app_path}/config/environment"
      assert_equal false, ActionDispatch::Cookies::CookieJar.always_write_cookie
    end

    test 'always_write_cookie can be overrided' do
      add_to_config <<-RUBY
        config.action_dispatch.always_write_cookie = false
      RUBY

      require 'rails'
      Rails.env = 'development'
      require "#{app_path}/config/environment"
      assert_equal false, ActionDispatch::Cookies::CookieJar.always_write_cookie
    end
  end
end
