require 'abstract_unit'
require 'multibyte_test_helpers'
require 'stringio'
require 'fileutils'
require 'tempfile'
require 'active_support/buffered_logger'
require 'active_support/testing/deprecation'

class BufferedLoggerTest < Test::Unit::TestCase
  include MultibyteTestHelpers
  include ActiveSupport::Testing::Deprecation

  Logger = ActiveSupport::BufferedLogger

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
    if str.respond_to?(:force_encoding)
      str.force_encoding("ASCII-8BIT")
    end

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
    if str.respond_to?(:force_encoding)
      str.force_encoding("ASCII-8BIT")
    end

    logger.add Logger::DEBUG, str
  ensure
    logger.close
    File.unlink fname
  end

  def test_should_default_logger_level_to_one_passed_while_creating_it
    logger = Logger.new(@output, Logger::ERROR)
    assert_equal Logger::ERROR, logger.level
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
      @logger.level = Logger::Severity.const_get(level) - 1
      assert @logger.send("#{level.downcase}?"), "didn't know if it was #{level.downcase}? or below"
    end
  end

  def test_should_create_the_log_directory_if_it_doesnt_exist
    tmp_directory = File.join(File.dirname(__FILE__), "tmp")
    log_file = File.join(tmp_directory, "development.log")
    FileUtils.rm_rf(tmp_directory)
    assert_deprecated do
      @logger  = Logger.new(log_file)
    end
    assert File.exist?(tmp_directory)
  end

  def test_buffer_multibyte
    @logger.info(UNICODE_STRING)
    @logger.info(BYTE_STRING)
    assert @output.string.include?(UNICODE_STRING)
    byte_string = @output.string.dup
    if byte_string.respond_to?(:force_encoding)
      byte_string.force_encoding("ASCII-8BIT")
    end
    assert byte_string.include?(BYTE_STRING)
  end
end
