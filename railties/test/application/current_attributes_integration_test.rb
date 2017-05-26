require "isolation/abstract_unit"
require "rack/test"

class CurrentAttributesIntegrationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include Rack::Test::Methods

  setup do
    build_app

    app_file "app/services/current.rb", <<-RUBY
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

    app_file "app/executor_intercept.rb", <<-RUBY
      check_state = -> { puts [ Current.customer.try(:name) || "noone", Time.zone.name ].join(",") }

      check_state.call

      Rails.application.executor.wrap do
        Current.customer = Customer.new("david")
        check_state.call
      end

      check_state.call
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
    Dir.chdir(app_path) do
      assert_equal "noone,UTC\ndavid,Copenhagen\nnoone,UTC\n", `bin/rails runner app/executor_intercept.rb`
    end
  end
end
