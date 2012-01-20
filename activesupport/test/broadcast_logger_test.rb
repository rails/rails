require 'abstract_unit'

module ActiveSupport
  class BroadcastLoggerTest < TestCase
    def test_debug
      log1 = FakeLogger.new
      log2 = FakeLogger.new

      logger = BroadcastLogger.new [log1, log2]
      logger.debug "foo"
      assert_equal 'foo', log1.adds.first[2]
      assert_equal 'foo', log2.adds.first[2]
    end

    def test_close
      log1 = FakeLogger.new
      log2 = FakeLogger.new

      logger = BroadcastLogger.new [log1, log2]
      logger.close
      assert log1.closed, 'should be closed'
      assert log2.closed, 'should be closed'
    end

    def test_chevrons
      log1 = FakeLogger.new
      log2 = FakeLogger.new

      logger = BroadcastLogger.new [log1, log2]
      logger << "foo"
      assert_equal %w{ foo }, log1.chevrons
      assert_equal %w{ foo }, log2.chevrons
    end

    class FakeLogger
      attr_reader :adds, :closed, :chevrons

      def initialize
        @adds     = []
        @closed   = false
        @chevrons = []
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
