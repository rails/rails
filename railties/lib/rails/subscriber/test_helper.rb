require 'rails/subscriber'
require 'active_support/notifications'

module Rails
  class Subscriber
    # Provides some helpers to deal with testing subscribers by setting up
    # notifications. Take for instance ActiveRecord subscriber tests:
    #
    #   module SubscriberTest
    #     Rails::Subscriber.add(:active_record, ActiveRecord::Railties::Subscriber.new)
    # 
    #     def test_basic_query_logging
    #       Developer.all
    #       wait
    #       assert_equal 1, @logger.logged(:debug).size
    #       assert_match /Developer Load/, @logger.logged(:debug).last
    #       assert_match /SELECT \* FROM "developers"/, @logger.logged(:debug).last
    #     end
    # 
    #     class SyncSubscriberTest < ActiveSupport::TestCase
    #       include Rails::Subscriber::SyncTestHelper
    #       include SubscriberTest
    #     end
    # 
    #     class AsyncSubscriberTest < ActiveSupport::TestCase
    #       include Rails::Subscriber::AsyncTestHelper
    #       include SubscriberTest
    #     end
    #   end
    #
    # All you need to do is to ensure that your subscriber is added to Rails::Subscriber,
    # as in the second line of the code above. The test helpers is reponsible for setting
    # up the queue, subscriptions and turning colors in logs off.
    #
    # The messages are available in the @logger instance, which is a logger with limited
    # powers (it actually do not send anything to your output), and you can collect them
    # doing @logger.logged(level), where level is the level used in logging, like info,
    # debug, warn and so on.
    #
    module TestHelper
      def setup
        Thread.abort_on_exception = true

        @logger   = MockLogger.new
        @notifier = ActiveSupport::Notifications::Notifier.new(queue)

        Rails::Subscriber.colorize_logging = false
        @notifier.subscribe { |*args| Rails::Subscriber.dispatch(args) }

        set_logger(@logger)
        ActiveSupport::Notifications.notifier = @notifier
      end

      def teardown
        set_logger(nil)
        ActiveSupport::Notifications.notifier = nil
        Thread.abort_on_exception = false
      end

      class MockLogger
        attr_reader :flush_count

        def initialize
          @flush_count = 0
          @logged = Hash.new { |h,k| h[k] = [] }
        end

        def method_missing(level, message)
          @logged[level] << message
        end

        def logged(level)
          @logged[level].compact.map { |l| l.to_s.strip }
        end

        def flush
          @flush_count += 1
        end
      end

      # Wait notifications to be published.
      def wait
        @notifier.wait
      end

      # Overwrite if you use another logger in your subscriber:
      #
      #   def logger
      #     ActiveRecord::Base.logger = @logger
      #   end
      #
      def set_logger(logger)
        Rails.logger = logger
      end
    end
    
    module SyncTestHelper
      include TestHelper

      def queue
        ActiveSupport::Notifications::Fanout.new(true)
      end
    end

    module AsyncTestHelper
      include TestHelper

      def queue
        ActiveSupport::Notifications::Fanout.new(false)
      end

      def wait
        sleep(0.01)
        super
      end
    end
  end
end