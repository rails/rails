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

  class NotificationsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "active_support/notifications"
      @events = []

      add_to_config <<-RUBY
        config.notifications.notifier = ActiveSupport::Notifications::Notifier.new(ApplicationTests::MyQueue.new)
      RUBY
    end

    test "new queue is set" do
      use_frameworks []
      require "#{app_path}/config/environment"

      assert_raise RuntimeError do
        ActiveSupport::Notifications.publish('foo')
      end
    end
  end
end
