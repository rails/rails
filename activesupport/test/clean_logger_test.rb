require 'abstract_unit'
require 'stringio'
require 'active_support/logger'

class CleanLoggerTest < ActiveSupport::TestCase
  def setup
    @out = StringIO.new
    @logger = ActiveSupport::Logger.new(@out)
  end

  def test_format_message
    @logger.error 'error'
    assert_equal "error\n", @out.string
  end

  def test_datetime_format
    @logger.formatter = Logger::Formatter.new
    @logger.formatter.datetime_format = "%Y-%m-%d"
    @logger.debug 'debug'
    assert_equal "%Y-%m-%d", @logger.formatter.datetime_format
    assert_match(/D, \[\d\d\d\d-\d\d-\d\d#\d+\] DEBUG -- : debug/, @out.string)
  end

  def test_nonstring_formatting
    an_object = [1, 2, 3, 4, 5]
    @logger.debug an_object
    assert_equal("#{an_object.inspect}\n", @out.string)
  end
end
