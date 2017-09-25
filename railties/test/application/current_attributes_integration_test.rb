# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

class CurrentAttributesIntegrationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include Rack::Test::Methods

  setup do
    build_app

    app_file "app/models/current.rb", <<-RUBY
      class Current < ActiveSupport::CurrentAttributes
        attribute :customer

        resets { Time.zone = "UTC" }

        def customer=(customer)
          super
          Time.zone = customer.try(:time_zone)
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

    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "/customers/:action", controller: :customers
      end
    RUBY

    app_file "app/controllers/customers_controller.rb", <<-RUBY
      class CustomersController < ApplicationController
        layout false

        def set_current_customer
          Current.customer = Customer.new("david")
          render :index
        end

        def set_no_customer
          render :index
        end
      end
    RUBY

    app_file "app/views/customers/index.html.erb", <<-RUBY
      <%= Current.customer.try(:name) || 'noone' %>,<%= Time.zone.name %>
    RUBY

    require "#{app_path}/config/environment"
  end

  teardown :teardown_app

  test "current customer is assigned and cleared" do
    get "/customers/set_current_customer"
    assert_equal 200, last_response.status
    assert_match(/david,Copenhagen/, last_response.body)

    get "/customers/set_no_customer"
    assert_equal 200, last_response.status
    assert_match(/noone,UTC/, last_response.body)
  end

  test "resets after execution" do
    assert_nil Current.customer
    assert_equal "UTC", Time.zone.name

    Rails.application.executor.wrap do
      Current.customer = Customer.new("david")

      assert_equal "david", Current.customer.name
      assert_equal "Copenhagen", Time.zone.name
    end

    assert_nil Current.customer
    assert_equal "UTC", Time.zone.name
  end
end
