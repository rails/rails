require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class FlashTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    test 'calling reset_session on request does not trigger an error for API apps' do
      add_to_config 'config.api_only = true'

      controller :test, <<-RUBY
        class TestController < ApplicationController
          def dump_flash
            request.reset_session
            render plain: 'It worked!'
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          get '/dump_flash' => "test#dump_flash"
        end
      RUBY

      app 'development'

      get '/dump_flash'

      assert_equal 200, last_response.status
      assert_equal 'It worked!', last_response.body

      refute Rails.application.middleware.include?(ActionDispatch::Flash)
    end
  end
end
