# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

class ActionControllerTestCaseIntegrationTest < ActionController::TestCase
  class_attribute :executor_around_each_request

  include ActiveSupport::Testing::Isolation

  setup do
    build_app

    app_file "app/models/current.rb", <<-RUBY
      class Current < ActiveSupport::CurrentAttributes
        attribute :customer

        resets { Time.zone = "UTC" }

        def customer=(customer)
          super
          Time.zone = customer&.time_zone
        end
      end
    RUBY

    app_file "app/models/customer.rb", <<-RUBY
      class Customer < Struct.new(:name)
        def time_zone
          "Copenhagen"
        end
      end
    RUBY

    remove_from_config '.*config\.load_defaults.*\n'
    add_to_config "config.active_support.executor_around_test_case = #{self.class.executor_around_each_request}"

    app_file "app/controllers/customers_controller.rb", <<-RUBY
      class CustomersController < ApplicationController
        layout false

        def get_current_customer
          render :index
        end

        def set_current_customer
          Current.customer = Customer.new("david")
          render :index
        end
      end
    RUBY

    app_file "app/views/customers/index.html.erb", <<-RUBY
      <%= Current.customer&.name || 'noone' %>,<%= Time.zone.name %>
    RUBY

    app_file "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
        get "/customers/:action", controller: :customers
      end
    RUBY

    require "#{app_path}/config/environment"

    @controller = CustomersController.new
    @routes = Rails.application.routes
  end

  teardown :teardown_app

  class WithExecutorIntegrationTest < ActionControllerTestCaseIntegrationTest
    self.executor_around_each_request = true

    test "current customer is cleared after each request" do
      assert Rails.application.config.active_support.executor_around_test_case
      assert ActionController::TestCase.executor_around_each_request

      get :get_current_customer
      assert_response :ok
      assert_match(/noone,UTC/, response.body)

      get :set_current_customer
      assert_response :ok
      assert_match(/david,Copenhagen/, response.body)

      get :get_current_customer
      assert_response :ok
      assert_match(/noone,UTC/, response.body)
    end
  end

  class WithoutExecutorIntegrationTest < ActionControllerTestCaseIntegrationTest
    self.executor_around_each_request = false

    test "current customer is not cleared after each request" do
      assert_not Rails.application.config.active_support.executor_around_test_case
      assert_not ActionController::TestCase.executor_around_each_request

      get :get_current_customer
      assert_response :ok
      assert_match(/noone,UTC/, response.body)

      get :set_current_customer
      assert_response :ok
      assert_match(/david,Copenhagen/, response.body)

      get :get_current_customer
      assert_response :ok
      assert_match(/david,Copenhagen/, response.body)
    end
  end
end
