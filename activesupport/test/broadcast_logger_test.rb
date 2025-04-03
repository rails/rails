# frozen_string_literal: true

require_relative "abstract_unit"

module ActiveSupport
  class BroadcastLoggerTest < TestCase
    attr_reader :logger, :log1, :log2

    setup do
      @log1 = FakeLogger.new
      @log2 = FakeLogger.new
      @logger = BroadcastLogger.new(@log1, @log2)
    end

    Logger::Severity.constants.each do |level_name|
      method = level_name.downcase
      level = Logger::Severity.const_get(level_name)

      test "##{method} adds the message to all loggers" do
        logger.public_send(method, "msg")

        assert_equal [level, "msg", nil], log1.adds.first
        assert_equal [level, "msg", nil], log2.adds.first
      end
    end

    test "#close broadcasts to all loggers" do
      logger.close

      assert log1.closed, "should be closed"
      assert log2.closed, "should be closed"
    end

    test "#<< shovels the value into all loggers" do
      logger << "foo"

      assert_equal %w{ foo }, log1.chevrons
      assert_equal %w{ foo }, log2.chevrons
    end

    test "#level= assigns the level to all loggers" do
      assert_equal ::Logger::DEBUG, log1.level
      logger.level = ::Logger::FATAL

      assert_equal ::Logger::FATAL, log1.level
      assert_equal ::Logger::FATAL, log2.level
    end

    test "#level returns the level of the logger with the lowest level" do
      log1.level = Logger::DEBUG

      assert_equal(Logger::DEBUG, logger.level)

      log1.level = Logger::FATAL
      log2.level = Logger::INFO

      assert_equal(Logger::INFO, logger.level)
    end

    test "#progname returns Broadcast literally when the user didn't change the progname" do
      assert_equal("Broadcast", logger.progname)
    end

    test "#progname= sets the progname on the Broadcast logger but doesn't modify the inner loggers" do
      assert_nil(log1.progname)
      assert_nil(log2.progname)

      logger.progname = "Foo"

      assert_equal("Foo", logger.progname)
      assert_nil(log1.progname)
      assert_nil(log2.progname)
    end

    test "#formatter= assigns to all the loggers" do
      logger.formatter = ::Logger::FATAL

      assert_equal ::Logger::FATAL, log1.formatter
      assert_equal ::Logger::FATAL, log2.formatter
    end

    test "#local_level= assigns the local_level to all loggers" do
      assert_equal ::Logger::DEBUG, log1.local_level
      logger.local_level = ::Logger::FATAL

      assert_equal ::Logger::FATAL, log1.local_level
      assert_equal ::Logger::FATAL, log2.local_level
    end

    test "severity methods get called on all loggers" do
      my_logger = Class.new(::Logger) do
        attr_reader :info_called

        def info(msg, &block)
          @info_called = true
        end
      end.new(StringIO.new)

      @logger.broadcast_to(my_logger)

      assert_changes(-> { my_logger.info_called }, from: nil, to: true) do
        @logger.info("message")
      end
    ensure
      @logger.stop_broadcasting_to(my_logger)
    end

    test "#silence does not break custom loggers" do
      new_logger = FakeLogger.new
      custom_logger = CustomLogger.new
      assert_respond_to new_logger, :silence
      assert_not_respond_to custom_logger, :silence

      logger = BroadcastLogger.new(custom_logger, new_logger)

      logger.silence do
        logger.error "from error"
        logger.unknown "from unknown"
      end

      assert_equal [[::Logger::ERROR, "from error", nil], [::Logger::UNKNOWN, "from unknown", nil]], custom_logger.adds
      assert_equal [[::Logger::ERROR, "from error", nil], [::Logger::UNKNOWN, "from unknown", nil]], new_logger.adds
    end

    test "#silence silences all loggers below the default level of ERROR" do
      logger.silence do
        logger.debug "test"
      end

      assert_equal [], log1.adds
      assert_equal [], log2.adds
    end

    test "#silence does not silence at or above ERROR" do
      logger.silence do
        logger.error "from error"
        logger.unknown "from unknown"
      end

      assert_equal [[::Logger::ERROR, "from error", nil], [::Logger::UNKNOWN, "from unknown", nil]], log1.adds
      assert_equal [[::Logger::ERROR, "from error", nil], [::Logger::UNKNOWN, "from unknown", nil]], log2.adds
    end

    test "#silence allows you to override the silence level" do
      logger.silence(::Logger::FATAL) do
        logger.error "unseen"
        logger.fatal "seen"
      end

      assert_equal [[::Logger::FATAL, "seen", nil]], log1.adds
      assert_equal [[::Logger::FATAL, "seen", nil]], log2.adds
    end

    test "stop broadcasting to a logger" do
      @logger.stop_broadcasting_to(@log2)

      @logger.info("Hello")

      assert_equal([[1, "Hello", nil]], @log1.adds)
      assert_empty(@log2.adds)
    end

    test "#broadcast on another broadcasted logger" do
      @log3 = FakeLogger.new
      @log4 = FakeLogger.new
      @broadcast2 = ActiveSupport::BroadcastLogger.new(@log3, @log4)

      @logger.broadcast_to(@broadcast2)
      @logger.info("Hello")

      assert_equal([[1, "Hello", nil]], @log1.adds)
      assert_equal([[1, "Hello", nil]], @log2.adds)
      assert_equal([[1, "Hello", nil]], @log3.adds)
      assert_equal([[1, "Hello", nil]], @log4.adds)
    end

    test "#debug? is true when at least one logger's level is at or above DEBUG level" do
      @log1.level = Logger::DEBUG
      @log2.level = Logger::FATAL

      assert_predicate(@logger, :debug?)
    end

    test "#debug? is false when all loggers are below DEBUG level" do
      @log1.level = Logger::ERROR
      @log2.level = Logger::FATAL

      assert_not_predicate(@logger, :debug?)
    end

    test "#info? is true when at least one logger's level is at or above INFO level" do
      @log1.level = Logger::DEBUG
      @log2.level = Logger::FATAL

      assert_predicate(@logger, :info?)
    end

    test "#info? is false when all loggers are below INFO" do
      @log1.level = Logger::ERROR
      @log2.level = Logger::FATAL

      assert_not_predicate(@logger, :info?)
    end

    test "#warn? is true when at least one logger's level is at or above WARN level" do
      @log1.level = Logger::DEBUG
      @log2.level = Logger::FATAL

      assert_predicate(@logger, :warn?)
    end

    test "#warn? is false when all loggers are below WARN" do
      @log1.level = Logger::ERROR
      @log2.level = Logger::FATAL

      assert_not_predicate(@logger, :warn?)
    end

    test "#error? is true when at least one logger's level is at or above ERROR level" do
      @log1.level = Logger::DEBUG
      @log2.level = Logger::FATAL

      assert_predicate(@logger, :error?)
    end

    test "#error? is false when all loggers are below ERROR" do
      @log1.level = Logger::FATAL
      @log2.level = Logger::FATAL

      assert_not_predicate(@logger, :error?)
    end

    test "#fatal? is true when at least one logger's level is at or above FATAL level" do
      @log1.level = Logger::DEBUG
      @log2.level = Logger::FATAL

      assert_predicate(@logger, :fatal?)
    end

    test "#fatal? is false when all loggers are below FATAL" do
      @log1.level = Logger::UNKNOWN
      @log2.level = Logger::UNKNOWN

      assert_not_predicate(@logger, :fatal?)
    end

    test "calling a method that no logger in the broadcast have implemented" do
      assert_raises(NoMethodError) do
        @logger.non_existing
      end
    end

    test "calling a method when *one* logger in the broadcast has implemented it" do
      logger = BroadcastLogger.new(CustomLogger.new)

      assert(logger.foo)
    end

    test "calling a method when *multiple* loggers in the broadcast have implemented it" do
      logger = BroadcastLogger.new(CustomLogger.new, CustomLogger.new)

      assert_equal([true, true], logger.foo)
    end

    test "calling a method when a subset of loggers in the broadcast have implemented" do
      logger = BroadcastLogger.new(CustomLogger.new, FakeLogger.new)

      assert(logger.foo)
    end

    test "calling a method that accepts a block" do
      logger = BroadcastLogger.new(CustomLogger.new)

      called = false
      logger.bar do
        called = true
      end
      assert(called)
    end

    test "calling a method that accepts args" do
      logger = BroadcastLogger.new(CustomLogger.new)

      assert(logger.baz("foo"))
    end

    test "calling a method that accepts kwargs" do
      logger = BroadcastLogger.new(CustomLogger.new)

      assert(logger.qux(param: "foo"))
    end

    test "#dup duplicates the broadcasts" do
      logger = CustomLogger.new
      logger.level = ::Logger::WARN
      broadcast_logger = BroadcastLogger.new(logger)

      duplicate = broadcast_logger.dup

      assert_equal ::Logger::WARN, duplicate.broadcasts.sole.level
      assert_not_same logger, duplicate.broadcasts.sole
      assert_same logger, broadcast_logger.broadcasts.sole
    end

    test "logging always returns true" do
      assert_equal true, @logger.info("Hello")
      assert_equal true, @logger.error("Hello")
    end

    Logger::Severity.constants.each do |level_name|
      method = level_name.downcase
      level = Logger::Severity.const_get(level_name)

      test "##{method} delegates keyword arguments to loggers" do
        logger = BroadcastLogger.new(KwargsAcceptingLogger.new)

        logger.public_send(method, "Hello", foo: "bar")
        assert_equal [[level, "#{{ foo: "bar" }} Hello", nil]], logger.broadcasts.sole.adds
      end
    end

    test "#add delegates keyword arguments to the loggers" do
      logger = BroadcastLogger.new(KwargsAcceptingLogger.new)

      logger.add(::Logger::INFO, "Hello", foo: "bar")
      assert_equal [[::Logger::INFO, "#{{ foo: "bar" }} Hello", nil]], logger.broadcasts.sole.adds
    end

    class CustomLogger
      attr_reader :adds, :closed, :chevrons
      attr_accessor :level, :progname, :formatter, :local_level

      def initialize
        @adds        = []
        @closed      = false
        @chevrons    = []
        @level       = ::Logger::DEBUG
        @local_level = ::Logger::DEBUG
        @progname    = nil
        @formatter   = nil
      end

      def foo
        true
      end

      def bar
        yield
      end

      def baz(param)
        true
      end

      def qux(param:)
        true
      end

      def debug(message, &block)
        add(::Logger::DEBUG, message, &block)
      end

      def info(message, &block)
        add(::Logger::INFO, message, &block)
      end

      def warn(message, &block)
        add(::Logger::WARN, message, &block)
      end

      def error(message, &block)
        add(::Logger::ERROR, message, &block)
      end

      def fatal(message, &block)
        add(::Logger::FATAL, message, &block)
      end

      def unknown(message, &block)
        add(::Logger::UNKNOWN, message, &block)
      end

      def <<(x)
        @chevrons << x
      end

      def add(message_level, message = nil, progname = nil, &block)
        @adds << [message_level, message, progname] if message_level >= local_level
      end

      def debug?
        level <= ::Logger::DEBUG
      end

      def info?
        level <= ::Logger::INFO
      end

      def warn?
        level <= ::Logger::WARN
      end

      def error?
        level <= ::Logger::ERROR
      end

      def fatal?
        level <= ::Logger::FATAL
      end

      def close
        @closed = true
      end
    end

    class FakeLogger < CustomLogger
      include ActiveSupport::LoggerSilence

      # LoggerSilence includes LoggerThreadSafeLevel which defines these as
      # methods, so we need to redefine them
      attr_accessor :level, :local_level
    end

    class KwargsAcceptingLogger < CustomLogger
      Logger::Severity.constants.each do |level_name|
        method = level_name.downcase
        define_method(method) do |message, **kwargs|
          add(Logger::Severity.const_get(level_name), "#{kwargs.inspect} #{message}")
        end
      end

      def add(severity, message = nil, **kwargs)
        return super(severity, "#{kwargs.inspect} #{message}") if kwargs.present?
        super
      end
    end
  end
end
