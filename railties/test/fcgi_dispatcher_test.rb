$:.unshift File.dirname(__FILE__) + "/mocks"

require 'test/unit'
require 'stringio'

if !defined?(RailsFCGIHandler)
  RAILS_ROOT = File.dirname(__FILE__)
  load File.dirname(__FILE__) + "/../dispatches/dispatch.fcgi"
end

class RailsFCGIHandler
  attr_reader :exit_code
  attr_accessor :thread

  def trap(signal, handler, &block)
    handler ||= block
    (@signal_handlers ||= Hash.new)[signal] = handler
  end

  def exit(code=0)
    @exit_code = code
    (thread || Thread.current).exit
  end

  def send_signal(which)
    @signal_handlers[which].call
  end
end

class RailsFCGIHandlerTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
    @handler = RailsFCGIHandler.new(@log)
    FCGI.time_to_sleep = nil
    FCGI.raise_exception = nil
    Dispatcher.time_to_sleep = nil
    Dispatcher.raise_exception = nil
  end

  def test_uninterrupted_processing
    @handler.process!
    assert_nil @handler.exit_code
    assert !@handler.please_exit_at_your_earliest_convenience
    assert !@handler.i_am_currently_processing_a_request
  end

  %w(HUP USR1).each do |signal|
    define_method("test_interrupted_via_#{signal}_when_not_in_request") do
      FCGI.time_to_sleep = 1
      @handler.thread = Thread.new { @handler.process! }
      sleep 0.1 # let the thread get started
      @handler.send_signal(signal)
      @handler.thread.join
      assert_equal 0, @handler.exit_code
      assert !@handler.please_exit_at_your_earliest_convenience
      assert !@handler.i_am_currently_processing_a_request
    end

    define_method("test_interrupted_via_#{signal}_when_in_request") do
      Dispatcher.time_to_sleep = 1
      @handler.thread = Thread.new { @handler.process! }
      sleep 0.1 # let the thread get started
      @handler.send_signal(signal)
      @handler.thread.join
      assert_nil @handler.exit_code
      assert @handler.please_exit_at_your_earliest_convenience
      assert !@handler.i_am_currently_processing_a_request
    end
  end

  %w(RuntimeError SignalException).each do |exception|
    define_method("test_#{exception}_in_fcgi") do
      FCGI.raise_exception = Object.const_get(exception)
      @handler.process!
      assert_match %r{Dispatcher failed to catch}, @log.string
      case exception
        when "RuntimeError"
          assert_match %r{almost killed}, @log.string
        when "SignalException"
          assert_match %r{\d killed}, @log.string
      end
    end

    define_method("test_#{exception}_in_dispatcher") do
      Dispatcher.raise_exception = Object.const_get(exception)
      @handler.process!
      assert_match %r{Dispatcher failed to catch}, @log.string
      case exception
        when "RuntimeError"
          assert_no_match %r{killed}, @log.string
        when "SignalException"
          assert_match %r{\d killed}, @log.string
      end
    end
  end
end
