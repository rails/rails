require 'abstract_unit'
require 'multibyte_test_helpers'
require 'stringio'
require 'fileutils'
require 'tempfile'
require 'active_support/concurrency/latch'

class LoggerTest < ActiveSupport::TestCase
  include MultibyteTestHelpers

  Logger = ActiveSupport::Logger

  def setup
    @message = "A debug message"
    @integer_message = 12345
    @output  = StringIO.new
    @logger  = Logger.new(@output)
  end

  def test_write_binary_data_to_existing_file
    t = Tempfile.new ['development', 'log']
    t.binmode
    t.write 'hi mom!'
    t.close

    f = File.open(t.path, 'w')
    f.binmode

    logger = Logger.new f
    logger.level = Logger::DEBUG

    str = "\x80"
    str.force_encoding("ASCII-8BIT")

    logger.add Logger::DEBUG, str
  ensure
    logger.close
    t.close true
  end

  def test_write_binary_data_create_file
    fname = File.join Dir.tmpdir, 'lol', 'rofl.log'
    FileUtils.mkdir_p File.dirname(fname)
    f = File.open(fname, 'w')
    f.binmode

    logger = Logger.new f
    logger.level = Logger::DEBUG

    str = "\x80"
    str.force_encoding("ASCII-8BIT")

    logger.add Logger::DEBUG, str
  ensure
    logger.close
    File.unlink fname
  end

  def test_should_log_debugging_message_when_debugging
    @logger.level = Logger::DEBUG
    @logger.add(Logger::DEBUG, @message)
    assert @output.string.include?(@message)
  end

  def test_should_not_log_debug_messages_when_log_level_is_info
    @logger.level = Logger::INFO
    @logger.add(Logger::DEBUG, @message)
    assert ! @output.string.include?(@message)
  end

  def test_should_add_message_passed_as_block_when_using_add
    @logger.level = Logger::INFO
    @logger.add(Logger::INFO) {@message}
    assert @output.string.include?(@message)
  end

  def test_should_add_message_passed_as_block_when_using_shortcut
    @logger.level = Logger::INFO
    @logger.info {@message}
    assert @output.string.include?(@message)
  end

  def test_should_convert_message_to_string
    @logger.level = Logger::INFO
    @logger.info @integer_message
    assert @output.string.include?(@integer_message.to_s)
  end

  def test_should_convert_message_to_string_when_passed_in_block
    @logger.level = Logger::INFO
    @logger.info {@integer_message}
    assert @output.string.include?(@integer_message.to_s)
  end

  def test_should_not_evaluate_block_if_message_wont_be_logged
    @logger.level = Logger::INFO
    evaluated = false
    @logger.add(Logger::DEBUG) {evaluated = true}
    assert evaluated == false
  end

  def test_should_not_mutate_message
    message_copy = @message.dup
    @logger.info @message
    assert_equal message_copy, @message
  end

  def test_should_know_if_its_loglevel_is_below_a_given_level
    Logger::Severity.constants.each do |level|
      next if level.to_s == 'UNKNOWN'
      @logger.level = Logger::Severity.const_get(level) - 1
      assert @logger.send("#{level.downcase}?"), "didn't know if it was #{level.downcase}? or below"
    end
  end

  def test_buffer_multibyte
    @logger.level = Logger::INFO
    @logger.info(UNICODE_STRING)
    @logger.info(BYTE_STRING)
    assert @output.string.include?(UNICODE_STRING)
    byte_string = @output.string.dup
    byte_string.force_encoding("ASCII-8BIT")
    assert byte_string.include?(BYTE_STRING)
  end

  def test_silencing_everything_but_errors
    @logger.silence do
      @logger.debug "NOT THERE"
      @logger.error "THIS IS HERE"
    end

    assert !@output.string.include?("NOT THERE")
    assert @output.string.include?("THIS IS HERE")
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

    latch  = ActiveSupport::Concurrency::Latch.new
    latch2 = ActiveSupport::Concurrency::Latch.new

    t = Thread.new do
      latch.await
      assert_level(Logger::INFO)
      latch2.release
    end

    @logger.silence(Logger::ERROR) do
      assert_level(Logger::ERROR)
      latch.release
      latch2.await
    end

    t.join
  end

  def test_logger_level_local_thread_safety
    @logger.level = Logger::INFO
    assert_level(Logger::INFO)

    thread_1_latch = ActiveSupport::Concurrency::Latch.new
    thread_2_latch = ActiveSupport::Concurrency::Latch.new

    threads = (1..2).collect do |thread_number|
      Thread.new do
        # force thread 2 to wait until thread 1 is already in @logger.silence
        thread_2_latch.await if thread_number == 2

        @logger.silence(Logger::ERROR) do
          assert_level(Logger::ERROR)
          @logger.silence(Logger::DEBUG) do
            # allow thread 2 to finish but hold thread 1
            if thread_number == 1
              thread_2_latch.release
              thread_1_latch.await
            end
            assert_level(Logger::DEBUG)
          end
        end

        # allow thread 1 to finish
        assert_level(Logger::INFO)
        thread_1_latch.release if thread_number == 2
      end
    end

    threads.each(&:join)
    assert_level(Logger::INFO)
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
