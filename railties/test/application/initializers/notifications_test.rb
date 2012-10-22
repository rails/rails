require "isolation/abstract_unit"

module ApplicationTests
  class NotificationsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    def instrument(*args, &block)
      ActiveSupport::Notifications.instrument(*args, &block)
    end

    def wait
      ActiveSupport::Notifications.notifier.wait
    end

    test "rails log_subscribers are added" do
      add_to_config <<-RUBY
        config.colorize_logging = false
      RUBY

      require "#{app_path}/config/environment"
      require "active_support/log_subscriber/test_helper"

      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
      ActiveRecord::Base.logger = logger

      # Mimic Active Record notifications
      instrument "sql.active_record", name: "SQL", sql: "SHOW tables"
      wait

      assert_equal 1, logger.logged(:debug).size
      assert_match(/SHOW tables/, logger.logged(:debug).last)
    end
  end
end
