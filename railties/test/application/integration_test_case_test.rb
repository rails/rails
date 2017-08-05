require "isolation/abstract_unit"

module ApplicationTests
  class IntegrationTestCaseTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup do
      build_app
    end

    teardown do
      teardown_app
    end

    test "resets Action Mailer test deliveries" do
      script("generate mailer BaseMailer welcome")

      app_file "test/integration/mailer_integration_test.rb", <<-RUBY
        require 'test_helper'

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

      output = Dir.chdir(app_path) { `bin/rails test 2>&1` }
      assert_equal 0, $?.to_i, output
      assert_match(/0 failures, 0 errors/, output)
    end
  end

  class IntegrationTestDefaultApp < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup do
      build_app
    end

    teardown do
      teardown_app
    end

    test "app method of integration tests returns test_app by default" do
      app_file "test/integration/default_app_test.rb", <<-RUBY
        require 'test_helper'

        class DefaultAppIntegrationTest < ActionDispatch::IntegrationTest
          def test_app_returns_action_dispatch_test_app_by_default
            assert_equal ActionDispatch.test_app, app
          end
        end
      RUBY

      output = Dir.chdir(app_path) { `bin/rails test 2>&1` }
      assert_equal 0, $?.to_i, output
      assert_match(/0 failures, 0 errors/, output)
    end
  end
end
