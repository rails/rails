require 'abstract_unit'

module ActiveSupport
  class BroadcastLoggerTest < TestCase
    attr_reader :logger, :log1, :log2
    def setup
      @log1 = FakeLogger.new
      @log2 = FakeLogger.new
      @log1.extend Logger.broadcast @log2
      @logger = @log1
    end

    def test_debug
      logger.debug "foo"
      assert_equal 'foo', log1.adds.first[2]
      assert_equal 'foo', log2.adds.first[2]
    end

    def test_close
      logger.close
      assert log1.closed, 'should be closed'
      assert log2.closed, 'should be closed'
    end

    def test_chevrons
      logger << "foo"
      assert_equal %w{ foo }, log1.chevrons
      assert_equal %w{ foo }, log2.chevrons
    end

    def test_level
      assert_nil logger.level
      logger.level = 10
      assert_equal 10, log1.level
      assert_equal 10, log2.level
    end

    def test_progname
      assert_nil logger.progname
      logger.progname = 10
      assert_equal 10, log1.progname
      assert_equal 10, log2.progname
    end

    def test_formatter
      assert_nil logger.formatter
      logger.formatter = 10
      assert_equal 10, log1.formatter
      assert_equal 10, log2.formatter
    end

    class FakeLogger
      attr_reader :adds, :closed, :chevrons
      attr_accessor :level, :progname, :formatter

      def initialize
        @adds      = []
        @closed    = false
        @chevrons  = []
        @level     = nil
        @progname  = nil
        @formatter = nil
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
