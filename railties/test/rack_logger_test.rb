require 'abstract_unit'
require 'active_support/testing/autorun'
require 'active_support/test_case'
require 'rails/rack/logger'
require 'logger'

module Rails
  module Rack
    class LoggerTest < ActiveSupport::TestCase
      class TestLogger < Rails::Rack::Logger
        NULL = ::Logger.new File::NULL

        attr_reader :logger

        def initialize(logger = NULL, taggers = nil, &block)
          super(->(_) { block.call; [200, {}, []] }, taggers)
          @logger = logger
        end

        def development?; false; end
      end

      class Subscriber < Struct.new(:starts, :finishes)
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
        @subscription = notifier.subscribe 'request.action_dispatch', subscriber
      end

      def teardown
        notifier.unsubscribe @subscription
      end

      def test_notification
        logger = TestLogger.new { }

        assert_difference('subscriber.starts.length') do
          assert_difference('subscriber.finishes.length') do
            logger.call('REQUEST_METHOD' => 'GET').last.close
          end
        end
      end

      def test_notification_on_raise
        logger = TestLogger.new do
          # using an exception class that is not a StandardError subclass on purpose
          raise NotImplementedError
        end

        assert_difference('subscriber.starts.length') do
          assert_difference('subscriber.finishes.length') do
            assert_raises(NotImplementedError) do
              logger.call 'REQUEST_METHOD' => 'GET'
            end
          end
        end
      end

      def test_started_response_message_with_flag_disabled
        logger_filename = "./rack_logger_test.log"
        File.open(logger_filename, "w")

        _logger = ::Logger.new(File.new(logger_filename, 'w+'))
        logger = TestLogger.new(_logger, nil, &Proc.new { [200, {}, []] })

        Rails.application.config.log_start_response_message = false
        logger.call('REQUEST_METHOD' => 'GET').last.close
        logger.logger.close

        found_resp_line = false
        File.open(logger_filename, "r+").each do |line|
          found_resp_line = true if line.include? "Started response HTTP "
        end
        assert !found_resp_line

        File.delete(logger_filename)
      end

      def test_started_response_message_with_flag_enabled
        logger_filename = "./rack_logger_test.log"
        File.open(logger_filename, "w")

        _logger = ::Logger.new(File.new(logger_filename, 'w+'))
        logger = TestLogger.new(_logger, nil, &Proc.new { [200, {}, []] })

        Rails.application.config.log_start_response_message = true
        logger.call('REQUEST_METHOD' => 'GET').last.close
        logger.logger.close

        found_resp_line = false
        File.open(logger_filename, "r+").each do |line|
          found_resp_line = true if line.include? "Started response HTTP "
        end

        assert found_resp_line

        File.delete(logger_filename)
      end
    end
  end
end
