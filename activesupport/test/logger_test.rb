# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "multibyte_test_helpers"
require "stringio"
require "fileutils"
require "tempfile"
require "tmpdir"
require "concurrent/atomics"

class LoggerTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  Logger = ActiveSupport::Logger

  def setup
    @message = "A debug message"
    @integer_message = 12345
    @output  = StringIO.new
    @logger  = Logger.new(@output)
  end

  def test_log_outputs_to
    assert Logger.logger_outputs_to?(@logger, @output),            "Expected logger_outputs_to? @output to return true but was false"
    assert Logger.logger_outputs_to?(@logger, @output, STDOUT),    "Expected logger_outputs_to? @output or STDOUT to return true but was false"

    assert_not Logger.logger_outputs_to?(@logger, STDOUT),         "Expected logger_outputs_to? to STDOUT to return false, but was true"
    assert_not Logger.logger_outputs_to?(@logger, STDOUT, STDERR), "Expected logger_outputs_to? to STDOUT or STDERR to return false, but was true"
    assert_not Logger.logger_outputs_to?(@logger, "log/production.log")
  end

  def test_log_outputs_to_with_a_broadcast_logger
    logger = ActiveSupport::BroadcastLogger.new(Logger.new(STDOUT))

    assert(Logger.logger_outputs_to?(logger, STDOUT))
    assert_not(Logger.logger_outputs_to?(logger, STDERR))

    logger.broadcast_to(Logger.new(STDERR))
    assert(Logger.logger_outputs_to?(logger, STDERR))
  end

  def test_log_outputs_to_with_a_filename
    t = Tempfile.new ["development", "log"]
    logger = ActiveSupport::BroadcastLogger.new(Logger.new(t.path))

    assert Logger.logger_outputs_to?(logger, t)
    assert Logger.logger_outputs_to?(logger, t.path)
    assert Logger.logger_outputs_to?(logger, File.join(File.dirname(t.path), ".", File.basename(t.path)))
    assert_not Logger.logger_outputs_to?(logger, "log/production.log")
    assert_not Logger.logger_outputs_to?(logger, STDOUT)
  ensure
    logger.close
    t.close true
  end

  def test_write_binary_data_to_existing_file
    t = Tempfile.new ["development", "log"]
    t.binmode
    t.write "hi mom!"
    t.close

    f = File.open(t.path, "w")
    f.binmode

    logger = Logger.new f
    logger.level = Logger::DEBUG

    str = +"\x80"
    str.force_encoding("ASCII-8BIT")

    assert_nothing_raised do
      logger.add Logger::DEBUG, str
    end
  ensure
    logger.close
    t.close true
  end

  def test_write_binary_data_create_file
    fname = File.join Dir.tmpdir, "lol", "rofl.log"
    FileUtils.mkdir_p File.dirname(fname)
    f = File.open(fname, "w")
    f.binmode

    logger = Logger.new f
    logger.level = Logger::DEBUG

    str = +"\x80"
    str.force_encoding("ASCII-8BIT")

    assert_nothing_raised do
      logger.add Logger::DEBUG, str
    end
  ensure
    logger.close
    File.unlink fname
  end

  def test_defaults_to_simple_formatter
    logger = Logger.new(@output)
    assert_instance_of ActiveSupport::Logger::SimpleFormatter, logger.formatter
  end

  def test_formatter_can_be_set_via_keyword_arg
    custom_formatter = ::Logger::Formatter.new
    logger = Logger.new(@output, formatter: custom_formatter)
    assert_same custom_formatter, logger.formatter
  end

  def test_should_log_debugging_message_when_debugging
    @logger.level = Logger::DEBUG
    @logger.add(Logger::DEBUG, @message)
    assert_includes @output.string, @message
  end

  def test_should_not_log_debug_messages_when_log_level_is_info
    @logger.level = Logger::INFO
    @logger.add(Logger::DEBUG, @message)
    assert_not_includes @output.string, @message
  end

  def test_should_add_message_passed_as_block_when_using_add
    @logger.level = Logger::INFO
    @logger.add(Logger::INFO) { @message }
    assert_includes @output.string, @message
  end

  def test_should_add_message_passed_as_block_when_using_shortcut
    @logger.level = Logger::INFO
    @logger.info { @message }
    assert_includes @output.string, @message
  end

  def test_should_convert_message_to_string
    @logger.level = Logger::INFO
    @logger.info @integer_message
    assert_includes @output.string, @integer_message.to_s
  end

  def test_should_convert_message_to_string_when_passed_in_block
    @logger.level = Logger::INFO
    @logger.info { @integer_message }
    assert_includes @output.string, @integer_message.to_s
  end

  def test_should_not_evaluate_block_if_message_wont_be_logged
    @logger.level = Logger::INFO
    evaluated = false
    @logger.add(Logger::DEBUG) { evaluated = true }
    assert evaluated == false
  end

  def test_should_not_mutate_message
    message_copy = @message.dup
    @logger.info @message
    assert_equal message_copy, @message
  end

  def test_should_know_if_its_loglevel_is_below_a_given_level
    Logger::Severity.constants.each do |level|
      next if level.to_s == "UNKNOWN"
      @logger.level = Logger::Severity.const_get(level) - 1
      assert @logger.public_send("#{level.downcase}?"), "didn't know if it was #{level.downcase}? or below"
    end
  end

  def test_buffer_multibyte
    @logger.level = Logger::INFO
    @logger.info(UNICODE_STRING)
    @logger.info(BYTE_STRING)
    assert_includes @output.string, UNICODE_STRING
    byte_string = @output.string.dup
    byte_string.force_encoding("ASCII-8BIT")
    assert_includes byte_string, BYTE_STRING
  end

  def test_silencing_everything_but_errors
    @logger.silence do
      @logger.debug "NOT THERE"
      @logger.error "THIS IS HERE"
    end

    assert_not_includes @output.string, "NOT THERE"
    assert_includes @output.string, "THIS IS HERE"
  end

  def test_unsilencing
    @logger.level = Logger::INFO

    @logger.debug "NOT THERE"

    @logger.silence Logger::DEBUG do
      @logger.debug "THIS IS HERE"
    end

    assert_not_includes @output.string, "NOT THERE"
    assert_includes @output.string, "THIS IS HERE"
  end

  def test_logger_silencing_works_for_broadcast
    another_output  = StringIO.new
    another_logger  = ActiveSupport::Logger.new(another_output)

    logger = ActiveSupport::BroadcastLogger.new(@logger, another_logger)

    logger.debug "CORRECT DEBUG"
    logger.silence do |logger|
      assert_kind_of ActiveSupport::BroadcastLogger, logger
      logger.debug "FAILURE"
      logger.error "CORRECT ERROR"
    end

    assert_includes @output.string, "CORRECT DEBUG"
    assert_includes @output.string, "CORRECT ERROR"
    assert_not_includes @output.string, "FAILURE"

    assert_includes another_output.string, "CORRECT DEBUG"
    assert_includes another_output.string, "CORRECT ERROR"
    assert_not another_output.string.include?("FAILURE")
  end

  def test_broadcast_silencing_does_not_break_plain_ruby_logger
    another_output  = StringIO.new
    another_logger  = ::Logger.new(another_output)

    logger = ActiveSupport::BroadcastLogger.new(@logger, another_logger)

    logger.debug "CORRECT DEBUG"
    logger.silence do |logger|
      assert_kind_of ActiveSupport::BroadcastLogger, logger
      logger.debug "FAILURE"
      logger.error "CORRECT ERROR"
    end

    assert_includes @output.string, "CORRECT DEBUG"
    assert_includes @output.string, "CORRECT ERROR"
    assert_not_includes @output.string, "FAILURE"

    assert_includes another_output.string, "CORRECT DEBUG"
    assert_includes another_output.string, "CORRECT ERROR"
    assert_includes another_output.string, "FAILURE"
    # We can't silence plain ruby Logger cause with thread safety
    # but at least we don't break it
  end

  def test_logger_level_per_object_thread_safety
    logger1 = Logger.new(StringIO.new)
    logger2 = Logger.new(StringIO.new)

    level = Logger::DEBUG
    assert_equal level, logger1.level, "Expected level #{level_name(level)}, got #{level_name(logger1.level)}"
    assert_equal level, logger2.level, "Expected level #{level_name(level)}, got #{level_name(logger2.level)}"

    logger1.level = Logger::ERROR
    assert_equal level, logger2.level, "Expected level #{level_name(level)}, got #{level_name(logger2.level)}"
  end

  def test_logger_level_main_thread_safety
    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    latch  = Concurrent::CountDownLatch.new
    latch2 = Concurrent::CountDownLatch.new

    t = Thread.new do
      latch.wait
      assert_level(Logger::INFO)
      latch2.count_down
    end

    @logger.silence(Logger::ERROR) do
      assert_level(Logger::ERROR)
      latch.count_down
      latch2.wait
    end

    t.join
  end

  def test_logger_level_local_thread_safety
    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    thread_1_latch = Concurrent::CountDownLatch.new
    thread_2_latch = Concurrent::CountDownLatch.new

    threads = (1..2).collect do |thread_number|
      Thread.new do
        # force thread 2 to wait until thread 1 is already in @logger.silence
        thread_2_latch.wait if thread_number == 2

        @logger.silence(Logger::ERROR) do
          assert_level(Logger::ERROR)
          @logger.silence(Logger::DEBUG) do
            # allow thread 2 to finish but hold thread 1
            if thread_number == 1
              thread_2_latch.count_down
              thread_1_latch.wait
            end
            assert_level(Logger::DEBUG)
          end
        end

        # allow thread 1 to finish
        assert_level(Logger::INFO)
        thread_1_latch.count_down if thread_number == 2
      end
    end

    threads.each(&:join)
    assert_level(Logger::INFO)
  end

  def test_logger_level_main_fiber_safety
    previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = :fiber

    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    fiber = Fiber.new do
      assert_level(Logger::INFO)
    end

    @logger.silence(Logger::ERROR) do
      assert_level(Logger::ERROR)
      fiber.resume
    end
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous_isolation_level
  end

  def test_logger_level_local_fiber_safety
    previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = :fiber

    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    another_fiber = Fiber.new do
      @logger.silence(Logger::ERROR) do
        assert_level(Logger::ERROR)
        @logger.silence(Logger::DEBUG) do
          assert_level(Logger::DEBUG)
        end
      end

      assert_level(Logger::INFO)
    end

    Fiber.new do
      @logger.silence(Logger::ERROR) do
        assert_level(Logger::ERROR)
        @logger.silence(Logger::DEBUG) do
          another_fiber.resume
          assert_level(Logger::DEBUG)
        end
      end

      assert_level(Logger::INFO)
    end.resume

    assert_level(Logger::INFO)
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous_isolation_level
  end

  def test_logger_level_thread_safety
    previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = :thread

    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    enumerator = Enumerator.new do |yielder|
      @logger.level = Logger::DEBUG
      yielder.yield @logger.level
    end
    assert_equal Logger::DEBUG, enumerator.next
    assert_level(Logger::DEBUG)
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous_isolation_level
  end

  def test_temporarily_logging_at_a_noisier_level
    @logger.level = Logger::INFO

    @logger.debug "NOT THERE"

    @logger.log_at Logger::DEBUG do
      @logger.debug "THIS IS HERE"
    end

    @logger.debug "NOT THERE"

    assert_not_includes @output.string, "NOT THERE"
    assert_includes @output.string, "THIS IS HERE"
  end

  def test_temporarily_logging_at_a_quieter_level
    @logger.log_at Logger::ERROR do
      @logger.debug "NOT THERE"
      @logger.error "THIS IS HERE"
    end

    assert_not_includes @output.string, "NOT THERE"
    assert_includes @output.string, "THIS IS HERE"
  end

  def test_temporarily_logging_at_a_symbolic_level
    @logger.log_at :error do
      @logger.debug "NOT THERE"
      @logger.error "THIS IS HERE"
    end

    assert_not_includes @output.string, "NOT THERE"
    assert_includes @output.string, "THIS IS HERE"
  end

  def test_log_at_only_impact_receiver
    logger2 = Logger.new(StringIO.new)
    assert_equal Logger::DEBUG, logger2.level
    assert_equal Logger::DEBUG, @logger.level

    @logger.log_at :error do
      assert_equal Logger::DEBUG, logger2.level
      assert_equal Logger::ERROR, @logger.level
    end
  end

  private
    def level_name(level)
      ::Logger::Severity.constants.find do |severity|
        Logger.const_get(severity) == level
      end.to_s
    end

    def assert_level(level)
      assert_equal level, @logger.level, "Expected level #{level_name(level)}, got #{level_name(@logger.level)}"
    end
end
