# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/autorun"
require "active_support/test_case"
require "rails/rack/logger"
require "logger"
require "active_support/log_subscriber/test_helper"

module Rails
  module Rack
    class LoggerTest < ActiveSupport::TestCase
      include ActiveSupport::LogSubscriber::TestHelper

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

      attr_reader :subscriber

      def setup
        super
        @subscriber = Subscriber.new
        @subscription = ActiveSupport::Notifications.notifier.subscribe "request.action_dispatch", subscriber
      end

      def teardown
        ActiveSupport::Notifications.notifier.unsubscribe @subscription
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

      def test_logger_is_flushed_after_request_finished
        logger_middleware = TestLogger.new { }

        flush_count_in_request_event = nil
        block_sub = @notifier.subscribe "request.action_dispatch" do |_event|
          flush_count_in_request_event = ActiveSupport::LogSubscriber.logger.flush_count
        end

        # Assert that we don't get a logger flush when we finish the response headers
        response_body = nil
        assert_no_difference("ActiveSupport::LogSubscriber.logger.flush_count") do
          response_body = logger_middleware.call("REQUEST_METHOD" => "GET").last
        end

        # Assert that we _do_ get a logger flush when we finish the response body
        assert_difference("ActiveSupport::LogSubscriber.logger.flush_count") do
          response_body.close
        end

        # And that the flush happens _after_ any LogSubscribers etc get run.
        flush_count = ActiveSupport::LogSubscriber.logger.flush_count
        assert_equal(1, flush_count - flush_count_in_request_event, "flush_all! should happen after event")
      ensure
        @notifier.unsubscribe block_sub
      end

      def test_logger_pushes_tags
        @logger = ActiveSupport::TaggedLogging.new(@logger)
        set_logger(@logger)

        taggers = ["tag1", ->(_req) { "tag2" }]
        logger_middleware = TestLogger.new(@logger, taggers: taggers) do
          # We can't really assert on logging something with the tags, because the MockLogger implementation
          # does not call the formatter (which is responsible for appending the tags)
          assert_equal(["tag1", "tag2"], @logger.formatter.current_tags)
        end
        block_sub = @notifier.subscribe "request.action_dispatch" do |_event|
          assert_equal(["tag1", "tag2"], @logger.formatter.current_tags)
        end

        # Call the app - it should log the inside app message
        response_body = logger_middleware.call("REQUEST_METHOD" => "GET").last
        # The tags should still be open as long as the request body isn't closed
        assert_equal(["tag1", "tag2"], @logger.formatter.current_tags)
        # And now should fire the request.action_dispatch event and call the event handler
        response_body.close
        # And it should also clear the tag stack.
        assert_equal([], @logger.formatter.current_tags)
      ensure
        @notifier.unsubscribe block_sub
      end
    end
  end
end
