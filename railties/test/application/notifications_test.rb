require "isolation/abstract_unit"

module ApplicationTests
  class NotificationsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    class MyQueue
      def publish(name, *args)
        raise name
      end
    end

    def setup
      build_app
      boot_rails
      require "rails"
      require "active_support/notifications"
      @events = []
      Rails::Initializer.run do |c|
        c.notifications.notifier = ActiveSupport::Notifications::Notifier.new(MyQueue.new)
      end
    end

    test "new queue is set" do
      assert_raise RuntimeError do
        ActiveSupport::Notifications.publish('foo')
      end
    end
  end
end
