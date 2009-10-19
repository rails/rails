require "isolation/abstract_unit"

module ApplicationTests
  class NotificationsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    class MyQueue
      attr_reader :events, :subscribers

      def initialize
        @events = []
        @subscribers = []
      end

      def publish(name, payload=nil)
        @events << name
      end

      def subscribe(pattern=nil, &block)
        @subscribers << pattern
      end
    end

    def setup
      build_app
      boot_rails
      require "rails"
      require "active_support/notifications"
      Rails::Initializer.run do |c|
        c.notifications.queue = MyQueue.new
        c.notifications.subscribe(/listening/) do
          puts "Cool"
        end
      end
    end

    test "new queue is set" do
      ActiveSupport::Notifications.instrument(:foo)
      assert_equal :foo, ActiveSupport::Notifications.queue.events.first
    end

    test "configuration subscribers are loaded" do
      assert_equal 1, ActiveSupport::Notifications.queue.subscribers.count { |s| s == /listening/ }
    end
  end
end
