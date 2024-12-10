# frozen_string_literal: true

require_relative "abstract_unit"

class LogBroadcastAndTaggingTest < ActiveSupport::TestCase
  setup do
    @sink1 = StringIO.new
    @sink2 = StringIO.new
    @logger1 = Logger.new(@sink1, formatter: ActiveSupport::Logger::SimpleFormatter.new)
    @logger2 = Logger.new(@sink2, formatter: ActiveSupport::Logger::SimpleFormatter.new)

    @broadcast = ActiveSupport::BroadcastLogger.new
    @broadcast.broadcast_to(@logger1, @logger2)
  end

  test "tag logs for the whole broadcast with a block" do
    log_count = 0

    @broadcast.tagged("BMX") do
      @broadcast.info("Hello")

      log_count += 1
    end

    assert_equal(1, log_count)
    assert_equal("[BMX] Hello\n", @sink1.string)
    assert_equal("[BMX] Hello\n", @sink2.string)
  end

  test "tag logs for the whole broadcast without a block" do
    @broadcast.tagged("BMX").info("Hello")

    assert_equal("[BMX] Hello\n", @sink1.string)
    assert_equal("[BMX] Hello\n", @sink2.string)

    @sink1.reopen
    @sink2.reopen
    @broadcast.info("Hello")

    assert_equal("Hello\n", @sink1.string)
    assert_equal("Hello\n", @sink2.string)
  end

  test "tag logs only for one sink" do
    @logger1.extend(ActiveSupport::TaggedLogging)
    @logger1.push_tags("BMX")

    @broadcast.info { "Hello" }

    assert_equal("[BMX] Hello\n", @sink1.string)
    assert_equal("Hello\n", @sink2.string)
  end

  test "tag logs for multiple sinks" do
    @logger1.extend(ActiveSupport::TaggedLogging)
    @logger1.push_tags("BMX")

    @logger2.extend(ActiveSupport::TaggedLogging)
    @logger2.push_tags("APP")

    @broadcast.info { "Hello" }

    assert_equal("[BMX] Hello\n", @sink1.string)
    assert_equal("[APP] Hello\n", @sink2.string)
  end

  test "tag logs for the whole broadcast and extra tags are added to one sink (block version)" do
    @logger1.extend(ActiveSupport::TaggedLogging)
    @logger1.push_tags("APP1")

    @logger2.extend(ActiveSupport::TaggedLogging)
    @logger2.push_tags("APP2")

    @broadcast.tagged("BMX") { @broadcast.info("Hello") }

    assert_equal("[BMX] [APP1] Hello\n", @sink1.string)
    assert_equal("[BMX] [APP2] Hello\n", @sink2.string)
  end

  test "tag logs for the whole broadcast and extra tags are added to one sink (non-block version)" do
    @logger1.extend(ActiveSupport::TaggedLogging)
    @logger1.push_tags("APP1")

    @logger2.extend(ActiveSupport::TaggedLogging)
    @logger2.push_tags("APP2")

    @broadcast.tagged("BMX").info("Hello")

    assert_equal("[BMX] [APP1] Hello\n", @sink1.string)
    assert_equal("[BMX] [APP2] Hello\n", @sink2.string)

    @sink1.reopen
    @sink2.reopen
    @broadcast.info("Hello")

    assert_equal("[APP1] Hello\n", @sink1.string)
    assert_equal("[APP2] Hello\n", @sink2.string)
  end

  test "can broadcast to another broadcast logger with tagging functionalities" do
    @sink3 = StringIO.new
    @sink4 = StringIO.new
    @logger3 = Logger.new(@sink3, formatter: ActiveSupport::Logger::SimpleFormatter.new)
    @logger4 = Logger.new(@sink4, formatter: ActiveSupport::Logger::SimpleFormatter.new)
    @broadcast2 = ActiveSupport::BroadcastLogger.new

    @broadcast2.broadcast_to(@logger3, @logger4)
    @broadcast.broadcast_to(@broadcast2)

    @broadcast2.push_tags("BROADCAST2")

    @broadcast.tagged("BMX") { @broadcast.info("Hello") }

    assert_equal("[BMX] Hello\n", @sink1.string)
    assert_equal("[BMX] Hello\n", @sink2.string)
    assert_equal("[BMX] [BROADCAST2] Hello\n", @sink3.string)
    assert_equal("[BMX] [BROADCAST2] Hello\n", @sink4.string)
  end

  test "#silence works while broadcasting to tagged loggers" do
    my_logger = Class.new(::Logger) do
      include ActiveSupport::LoggerSilence
    end

    logger1_io = StringIO.new
    logger2_io = StringIO.new

    logger1 = my_logger.new(logger1_io).extend(ActiveSupport::TaggedLogging)
    logger2 = my_logger.new(logger2_io).extend(ActiveSupport::TaggedLogging)

    broadcast = ActiveSupport::BroadcastLogger.new(logger1, logger2)

    broadcast.tagged("TEST") do
      broadcast.silence do
        broadcast.info("Silenced")
      end

      broadcast.info("Not silenced")
    end

    assert_equal("[TEST] Not silenced\n", logger1_io.string)
    assert_equal("[TEST] Not silenced\n", logger2_io.string)
  end
end
