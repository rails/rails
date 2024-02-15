# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  class IntegrationTestCaseTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    setup do
      build_app
    end

    teardown do
      teardown_app
    end

    test "resets Action Mailer test deliveries" do
      rails "generate", "mailer", "BaseMailer", "welcome"

      app_file "test/integration/mailer_integration_test.rb", <<-RUBY
        require "test_helper"

        class MailerIntegrationTest < ActionDispatch::IntegrationTest
          setup do
            @old_delivery_method = ActionMailer::Base.delivery_method
            ActionMailer::Base.delivery_method = :test
          end

          teardown do
            ActionMailer::Base.delivery_method = @old_delivery_method
          end

          2.times do |i|
            define_method "test_resets_deliveries_\#{i}" do
              BaseMailer.welcome.deliver_now
              assert_equal 1, ActionMailer::Base.deliveries.count
            end
          end
        end
      RUBY

      with_rails_env("test") { rails("db:migrate") }
      output = rails("test")
      assert_match(/0 failures, 0 errors/, output)
    end
  end

  class IntegrationTestDefaultApp < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    setup do
      build_app
    end

    teardown do
      teardown_app
    end

    test "app method of integration tests returns test_app by default" do
      app_file "test/integration/default_app_test.rb", <<-RUBY
        require "test_helper"

        class DefaultAppIntegrationTest < ActionDispatch::IntegrationTest
          def test_app_returns_action_dispatch_test_app_by_default
            assert_equal ActionDispatch.test_app, app
          end
        end
      RUBY

      with_rails_env("test") { rails("db:migrate") }
      output = rails("test")
      assert_match(/0 failures, 0 errors/, output)
    end
  end

  class LocalCacheTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    setup :build_app
    teardown :teardown_app

    test "with_local_cache isn't cleared between requests" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get :customer, to: "customer#show"
          get :cached_customer, to: "customer#show_with_cache"
        end
      RUBY

      app_file "app/controllers/customer_controller.rb", <<-RUBY
        class CustomerController < ApplicationController
          def show
            Rails.cache.fetch("customer") { "David" }
            head(:ok)
          end

          def show_with_cache
            if customer = Rails.cache.read("customer")
              render(plain: customer, status: :ok)
            else
              render(plain: "Cache miss", status: :bad_request)
            end
          end
        end
      RUBY

      app_file "test/integration/customer_integration_test.rb", <<-RUBY
        require "test_helper"

        class CustomerIntegrationTest < ActionDispatch::IntegrationTest
          def test_cache_is_cleared_on_each_request
            get("/customer")

            assert_response(:ok)
            assert_nil(Rails.cache.read("customer"), "The cache was not cleared")
          end

          def test_cache_is_not_cleared_after_the_request
            Rails.cache.with_local_cache do
              get("/customer")

              assert_response(:ok)
              assert_equal("David", Rails.cache.read("customer"))
            end

            assert_nil(Rails.cache.read("customer"), "The cache was not cleared")
          end

          def test_cache_is_hit
            Rails.cache.with_local_cache do
              get("/customer")
              assert_response(:ok)
              assert_equal("David", Rails.cache.read("customer"))

              get("/cached_customer")
              assert_response(:ok)
              assert_equal("David", response.body)
            end

            assert_nil(Rails.cache.read("customer"), "The cache was not cleared")
          end
        end
      RUBY

      with_rails_env("test") { rails("db:migrate") }
      output = rails("test")
      assert_match(/3 runs, 10 assertions, 0 failures, 0 errors/, output)
    end
  end
end
