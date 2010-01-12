require "isolation/abstract_unit"

module ApplicationTests
  class MyQueue
    def publish(name, *args)
      raise name
    end

    # Not a full queue implementation
    def method_missing(name, *args, &blk)
      self
    end
  end

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

    test "new queue is set" do
      # We don't want to load all frameworks, so remove them and clean up environments.
      use_frameworks []
      FileUtils.rm_rf("#{app_path}/config/environments")

      add_to_config <<-RUBY
        config.notifications.notifier = ActiveSupport::Notifications::Notifier.new(ApplicationTests::MyQueue.new)
      RUBY

      require "#{app_path}/config/environment"

      assert_raise RuntimeError do
        ActiveSupport::Notifications.publish('foo')
      end
    end

    test "rails subscribers are added" do
      add_to_config <<-RUBY
        config.colorize_logging = false
      RUBY

      require "#{app_path}/config/environment"

      ActiveRecord::Base.logger = logger = MockLogger.new

      # Mimic an ActiveRecord notifications
      instrument "active_record.sql", :name => "SQL", :sql => "SHOW tables"
      wait

      assert_equal 1, logger.logged.size
      assert_match /SHOW tables/, logger.logged.last
    end
  end
end
