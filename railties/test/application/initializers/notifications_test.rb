require "isolation/abstract_unit"

module ApplicationTests
  class MockLogger
    def method_missing(*args)
      @logged ||= []
      @logged << args.last
    end

    def logged
      @logged.compact.map { |l| l.to_s.strip }
    end
  end

  class NotificationsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
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

      ActiveRecord::Base.logger = logger = MockLogger.new

      # Mimic ActiveRecord notifications
      instrument "sql.active_record", :name => "SQL", :sql => "SHOW tables"
      wait

      assert_equal 1, logger.logged.size
      assert_match /SHOW tables/, logger.logged.last
    end
  end
end
