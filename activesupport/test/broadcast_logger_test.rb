require 'abstract_unit'

module ActiveSupport
  class BroadcastLoggerTest < TestCase
    attr_reader :logger, :receiving_logger
    def setup
      @logger = FakeLogger.new
      @receiving_logger = FakeLogger.new
      @logger.extend Logger.broadcast @receiving_logger
    end

    def test_debug
      logger.debug "foo"
      assert_equal 'foo', logger.adds.first[2]
      assert_equal 'foo', receiving_logger.adds.first[2]
    end

    def test_debug_without_message_broadcasts
      logger.broadcast_messages = false
      logger.debug "foo"
      assert_equal 'foo', logger.adds.first[2]
      assert_equal [], receiving_logger.adds
    end

    def test_close
      logger.close
      assert logger.closed, 'should be closed'
      assert receiving_logger.closed, 'should be closed'
    end

    def test_chevrons
      logger << "foo"
      assert_equal %w{ foo }, logger.chevrons
      assert_equal %w{ foo }, receiving_logger.chevrons
    end

    def test_chevrons_without_message_broadcasts
      logger.broadcast_messages = false
      logger << "foo"
      assert_equal %w{ foo }, logger.chevrons
      assert_equal [], receiving_logger.chevrons
    end

    def test_level
      assert_nil logger.level
      logger.level = 10
      assert_equal 10, logger.level
      assert_equal 10, receiving_logger.level
    end

    def test_progname
      assert_nil logger.progname
      logger.progname = 10
      assert_equal 10, logger.progname
      assert_equal 10, receiving_logger.progname
    end

    def test_formatter
      assert_nil logger.formatter
      logger.formatter = 10
      assert_equal 10, logger.formatter
      assert_equal 10, receiving_logger.formatter
    end

    class FakeLogger
      attr_reader :adds, :closed, :chevrons
      attr_accessor :level, :progname, :formatter, :broadcast_messages

      def initialize
        @adds      = []
        @closed    = false
        @chevrons  = []
        @level     = nil
        @progname  = nil
        @formatter = nil
        @broadcast_messages = true
      end

      def debug msg, &block
        add(:omg, nil, msg, &block)
      end

      def << x
        @chevrons << x
      end

      def add(*args)
        @adds << args
      end

      def close
        @closed = true
      end
    end
  end
end
