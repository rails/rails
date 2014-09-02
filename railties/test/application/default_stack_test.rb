# -*- coding: utf-8 -*-
require 'isolation/abstract_unit'
require 'rack/test'
require 'active_support/json'

module ApplicationTests
  class DefaultStackTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(initializers: true)
      boot_rails
    end

    def teardown
      teardown_app
    end

    test "the sanitizer helper" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render text: self.class.helpers.class.sanitizer_vendor
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY

      require "#{app_path}/config/environment"

      get "/foo"
      assert_equal 'Rails::Html::Sanitizer', last_response.body.strip
    end
  end
end
