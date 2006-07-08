require File.dirname(__FILE__) + '/abstract_unit'
require 'stringio'

class CleanLoggerTest < Test::Unit::TestCase
  def setup
    @out = StringIO.new
    @logger = Logger.new(@out)
  end

  def test_format_message
    @logger.error 'error'
    assert_equal "error\n", @out.string
  end

  def test_silence
    # Without yielding self.
    @logger.silence do
      @logger.debug  'debug'
      @logger.info   'info'
      @logger.warn   'warn'
      @logger.error  'error'
      @logger.fatal  'fatal'
    end

    # Yielding self.
    @logger.silence do |logger|
      logger.debug  'debug'
      logger.info   'info'
      logger.warn   'warn'
      logger.error  'error'
      logger.fatal  'fatal'
    end

    # Silencer off.
    Logger.silencer = false
    @logger.silence do |logger|
      logger.warn   'unsilenced'
    end
    Logger.silencer = true

    assert_equal "error\nfatal\nerror\nfatal\nunsilenced\n", @out.string
  end
end

class CleanLogger_182_to_183_Test < Test::Unit::TestCase
  def setup
    silence_warnings do
      if Logger.method_defined?(:formatter=)
        Logger.send(:alias_method, :hide_formatter=, :formatter=)
        Logger.send(:undef_method, :formatter=)
      else
        Logger.send(:define_method, :formatter=) { }
      end
      load File.dirname(__FILE__) + '/../lib/active_support/clean_logger.rb'
    end

    @out = StringIO.new
    @logger = Logger.new(@out)
    @logger.progname = 'CLEAN LOGGER TEST'
  end

  def teardown
    silence_warnings do
      if Logger.method_defined?(:hide_formatter=)
        Logger.send(:alias_method, :formatter=, :hide_formatter=)
      else
        Logger.send(:undef_method, :formatter=)
      end
      load File.dirname(__FILE__) + '/../lib/active_support/clean_logger.rb'
    end
  end

  # Since we've fooled Logger into thinking we're on 1.8.2 if we're on 1.8.3
  # and on 1.8.3 if we're on 1.8.2, it'll define format_message with the
  # wrong order of arguments and therefore print progname instead of msg.
  def test_format_message_with_faked_version
    @logger.error 'error'
    assert_equal "CLEAN LOGGER TEST\n", @out.string
  end
end
