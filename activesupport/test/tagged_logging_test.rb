# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/logger"
require "active_support/tagged_logging"

class TaggedLoggingTest < ActiveSupport::TestCase
  class MyLogger < ::ActiveSupport::Logger
    def flush(*)
      info "[FLUSHED]"
    end
  end

  setup do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.new(MyLogger.new(@output))
  end

  test "sets logger.formatter if missing and extends it with a tagging API" do
    logger = Logger.new(StringIO.new)
    assert_nil logger.formatter

    other_logger = ActiveSupport::TaggedLogging.new(logger)
    assert_not_nil other_logger.formatter
    assert_respond_to other_logger.formatter, :tagged
  end

  test "tagged once" do
    @logger.tagged("BCX") { @logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "tagged twice" do
    @logger.tagged("BCX") { @logger.tagged("Jason") { @logger.info "Funky time" } }
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test "tagged thrice at once" do
    @logger.tagged("BCX", "Jason", "New") { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged with an array" do
    @logger.tagged(%w(BCX Jason New)) { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged are flattened" do
    @logger.tagged("BCX", %w(Jason New)) { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "push and pop tags directly" do
    assert_equal %w(A B C), @logger.push_tags("A", ["B", "  ", ["C"]])
    @logger.info "a"
    assert_equal %w(C), @logger.pop_tags
    @logger.info "b"
    assert_equal %w(B), @logger.pop_tags(1)
    @logger.info "c"
    assert_equal [], @logger.clear_tags!
    @logger.info "d"
    assert_equal "[A] [B] [C] a\n[A] [B] b\n[A] c\nd\n", @output.string
  end

  test "does not strip message content" do
    @logger.info "  Hello"
    assert_equal "  Hello\n", @output.string
  end

  test "provides access to the logger instance" do
    @logger.tagged("BCX") { |logger| logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "tagged once with blank and nil" do
    @logger.tagged(nil, "", "New") { @logger.info "Funky time" }
    assert_equal "[New] Funky time\n", @output.string
  end

  test "keeps each tag in their own thread" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.info "Dull story"
        @logger.tagged("OMG") { @logger.info "Cool story" }
      end.join
      @logger.info "Funky time"
    end
    assert_equal "Dull story\n[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test "keeps each tag in their own thread even when pushed directly" do
    Thread.new do
      @logger.push_tags("OMG")
      @logger.info "Cool story"
    end.join
    @logger.info "Funky time"
    assert_equal "[OMG] Cool story\nFunky time\n", @output.string
  end

  test "keeps each tag in their own instance" do
    other_output = StringIO.new
    other_logger = ActiveSupport::TaggedLogging.new(MyLogger.new(other_output))
    @logger.tagged("OMG") do
      other_logger.tagged("BCX") do
        @logger.info "Cool story"
        other_logger.info "Funky time"
      end
    end
    assert_equal "[OMG] Cool story\n", @output.string
    assert_equal "[BCX] Funky time\n", other_output.string
  end

  test "does not share the same formatter instance of the original logger" do
    other_logger = ActiveSupport::TaggedLogging.new(@logger)

    @logger.tagged("OMG") do
      other_logger.tagged("BCX") do
        @logger.info "Cool story"
        other_logger.info "Funky time"
      end
    end
    assert_equal "[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test "cloned formatter does not share thread key even after access" do
    @logger.tagged("TAG1") { }

    other_logger = ActiveSupport::TaggedLogging.new(@logger)
    other_logger.push_tags("TAG2")

    assert_equal [], @logger.formatter.current_tags
    assert_equal ["TAG2"], other_logger.formatter.current_tags
  end

  test "cleans up the taggings on flush" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.tagged("OMG") do
          @logger.flush
          @logger.info "Cool story"
        end
      end.join
    end
    assert_equal "[FLUSHED]\nCool story\n", @output.string
  end

  test "mixed levels of tagging" do
    @logger.tagged("BCX") do
      @logger.tagged("Jason") { @logger.info "Funky time" }
      @logger.info "Junky time!"
    end

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end

  test "implicit logger instance" do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.logger(@output)

    @logger.tagged("BCX") { @logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end
end

class TaggedLoggingWithoutBlockTest < ActiveSupport::TestCase
  setup do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.new(Logger.new(@output))
  end

  test "tagged once" do
    @logger.tagged("BCX").info "Funky time"
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "tagged twice" do
    @logger.tagged("BCX").tagged("Jason").info "Funky time"
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test "tagged thrice at once" do
    @logger.tagged("BCX", "Jason", "New").info "Funky time"
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged are flattened" do
    @logger.tagged("BCX", %w(Jason New)).info "Funky time"
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged once with blank and nil" do
    @logger.tagged(nil, "", "New").info "Funky time"
    assert_equal "[New] Funky time\n", @output.string
  end

  test "shares tags across threads" do
    logger = @logger.tagged("BCX")

    Thread.new do
      logger.info "Dull story"
      logger.tagged("OMG").info "Cool story"
    end.join

    logger.info "Funky time"

    assert_equal "[BCX] Dull story\n[BCX] [OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test "keeps each tag in their own instance" do
    other_output = StringIO.new
    other_logger = ActiveSupport::TaggedLogging.new(Logger.new(other_output))

    tagged_logger = @logger.tagged("OMG")
    other_tagged_logger = other_logger.tagged("BCX")
    tagged_logger.info "Cool story"
    other_tagged_logger.info "Funky time"

    assert_equal "[OMG] Cool story\n", @output.string
    assert_equal "[BCX] Funky time\n", other_output.string
  end

  test "does not share the same formatter instance of the original logger" do
    other_logger = ActiveSupport::TaggedLogging.new(@logger)

    tagged_logger = @logger.tagged("OMG")
    other_tagged_logger = other_logger.tagged("BCX")
    tagged_logger.info "Cool story"
    other_tagged_logger.info "Funky time"

    assert_equal "[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test "mixed levels of tagging" do
    logger = @logger.tagged("BCX")
    logger.tagged("Jason").info "Funky time"
    logger.info "Junky time!"

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end

  test "keeps broadcasting functionality" do
    broadcast_output = StringIO.new
    broadcast_logger = ActiveSupport::BroadcastLogger.new(Logger.new(broadcast_output), @logger)
    logger_with_tags = ActiveSupport::TaggedLogging.new(broadcast_logger)

    tagged_logger = logger_with_tags.tagged("OMG")
    tagged_logger.info "Broadcasting..."

    assert_equal "[OMG] Broadcasting...\n", @output.string
    assert_equal "[OMG] Broadcasting...\n", broadcast_output.string
  end

  test "keeps formatter singleton class methods" do
    plain_output = StringIO.new
    plain_logger = Logger.new(plain_output)
    plain_logger.formatter = Logger::Formatter.new
    plain_logger.formatter.extend(Module.new {
      def crozz_method
      end
    })

    tagged_logger = ActiveSupport::TaggedLogging.new(plain_logger)
    assert_respond_to tagged_logger.formatter, :tagged
    assert_respond_to tagged_logger.formatter, :crozz_method
  end

  test "accepts non-String objects" do
    @logger.tagged("tag") { @logger.info [1, 2, 3] }
    assert_equal "[tag] [1, 2, 3]\n", @output.string
  end

  test "formatter works when frozen" do
    @logger.formatter.freeze
    @logger.info "frozen"
    assert_equal "frozen\n", @output.string
  end

  test "keeps block-scoped tags in their own thread when using a tagged logger without block" do
    logger = @logger.tagged("BASE_TAG")
    logger.tagged("BCX") do
      Thread.new do
        logger.info "Dull story"
        logger.tagged("OMG") { logger.info "Cool story" }
      end.join
      logger.info "Funky time"
    end
    assert_equal "[BASE_TAG] Dull story\n[BASE_TAG] [OMG] Cool story\n[BASE_TAG] [BCX] Funky time\n", @output.string
  end

  test "concurrent threads tagging a logger without block do not leak tags" do
    logger = @logger.tagged("BASE")

    t1 = Thread.new do
      logger.tagged("T1") do
        sleep 0.05
        logger.info "thread 1"
      end
    end

    t2 = Thread.new do
      sleep 0.02
      logger.tagged("T2") do
        logger.info "thread 2"
      end
    end

    [t1, t2].each(&:join)

    assert_includes @output.string, "[BASE] [T1] thread 1\n"
    assert_includes @output.string, "[BASE] [T2] thread 2\n"
    assert_not_includes @output.string, "[T1] [T2]"
    assert_not_includes @output.string, "[T2] [T1]"
  end

  test "push and pop tags directly on logger with local tags" do
    logger = @logger.tagged("BASE")
    assert_equal ["A", "B"], logger.push_tags("A", "B")
    logger.info "a"
    assert_equal ["B"], logger.pop_tags
    logger.info "b"
    assert_equal [], logger.clear_tags!
    logger.info "c"

    assert_equal "[BASE] [A] [B] a\n[BASE] [A] b\n[BASE] c\n", @output.string
  end

  test "flush clears dynamic tags but preserves local tags" do
    logger = @logger.tagged("BASE")
    logger.tagged("DYNAMIC") do
      logger.flush
      logger.info "after flush"
    end
    assert_equal "[BASE] after flush\n", @output.string
  end

  test "cloned logger with local tags isolates dynamic tags" do
    logger1 = @logger.tagged("A")
    logger2 = logger1.clone

    logger2.push_tags("B")

    assert_equal ["A"], logger1.formatter.current_tags
    assert_equal ["A", "B"], logger2.formatter.current_tags
  end
end
