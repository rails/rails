require File.dirname(__FILE__) + '/abstract_unit'
require 'stringio'

class BufferedLoggerTest < Test::Unit::TestCase
  def setup
    @message = "A debug message"
    @integer_message = 12345
    @output  = StringIO.new
    @logger  = ActiveSupport::BufferedLogger.new(@output)
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
end
