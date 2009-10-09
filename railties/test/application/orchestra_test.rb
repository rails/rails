require "isolation/abstract_unit"
require "active_support/orchestra"

module ApplicationTests
  class OrchestraTest < Test::Unit::TestCase

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

      Rails::Initializer.run do |c|
        c.orchestra.queue = MyQueue.new
        c.orchestra.subscribe(/listening/) do
          puts "Cool"
        end
      end
    end

    test "new queue is set" do
      ActiveSupport::Orchestra.instrument(:foo)
      assert_equal :foo, ActiveSupport::Orchestra.queue.events.first
    end

    test "frameworks subscribers are loaded" do
      assert_equal 1, ActiveSupport::Orchestra.queue.subscribers.count { |s| s == "sql" }
    end

    test "configuration subscribers are loaded" do
      assert_equal 1, ActiveSupport::Orchestra.queue.subscribers.count { |s| s == /listening/ }
    end
  end
end
