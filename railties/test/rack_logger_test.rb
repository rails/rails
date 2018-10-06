# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/autorun"
require "active_support/test_case"
require "rails/rack/logger"
require "logger"

module Rails
  module Rack
    class LoggerTest < ActiveSupport::TestCase
      class TestLogger < Rails::Rack::Logger
        NULL = ::Logger.new File::NULL

        attr_reader :logger

        def initialize(logger = NULL, app: nil, taggers: nil, &block)
          app ||= ->(_) { block.call; [200, {}, []] }
          super(app, taggers)
          @logger = logger
        end

        def development?; false; end
      end

      class TestApp < Struct.new(:response)
        def call(_env)
          response
        end
      end

      Subscriber = Struct.new(:starts, :finishes) do
        def initialize(starts = [], finishes = [])
          super
        end

        def start(name, id, payload)
          starts << [name, id, payload]
        end

        def finish(name, id, payload)
          finishes << [name, id, payload]
        end
      end

      attr_reader :subscriber, :notifier

      def setup
        @subscriber = Subscriber.new
        @notifier = ActiveSupport::Notifications.notifier
        @subscription = notifier.subscribe "request.action_dispatch", subscriber
      end

      def teardown
        notifier.unsubscribe @subscription
      end

      def test_notification
        logger = TestLogger.new { }

        assert_difference("subscriber.starts.length") do
          assert_difference("subscriber.finishes.length") do
            logger.call("REQUEST_METHOD" => "GET").last.close
          end
        end
      end

      def test_notification_on_raise
        logger = TestLogger.new do
          # using an exception class that is not a StandardError subclass on purpose
          raise NotImplementedError
        end

        assert_difference("subscriber.starts.length") do
          assert_difference("subscriber.finishes.length") do
            assert_raises(NotImplementedError) do
              logger.call "REQUEST_METHOD" => "GET"
            end
          end
        end
      end

      def test_logger_does_not_mutate_app_return
        response = [].freeze
        app = TestApp.new(response)
        logger = TestLogger.new(app: app)
        assert_no_changes("response") do
          assert_nothing_raised do
            logger.call("REQUEST_METHOD" => "GET")
          end
        end
      end
    end
  end
end
