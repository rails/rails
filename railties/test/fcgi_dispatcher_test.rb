require File.dirname(__FILE__) + "/abstract_unit"

begin # rescue LoadError

require 'mocha'
require 'stubba'
  
$:.unshift File.dirname(__FILE__) + "/mocks"

require 'stringio'

# Stubs
require 'fcgi_handler'
require 'routes'
require 'stubbed_breakpoint'
require 'stubbed_kernel'

class RailsFCGIHandler
  attr_reader :exit_code
  attr_reader :reloaded
  attr_accessor :thread
  attr_reader :gc_runs

  def trap(signal, handler, &block)
    handler ||= block
    (@signal_handlers ||= Hash.new)[signal] = handler
  end

  def exit(code=0)
    @exit_code = code
    (thread || Thread.current).exit
  end

  def send_signal(which)
    @signal_handlers[which].call(which)
  end
  
  def breakpoint
  end

  alias_method :old_run_gc!, :run_gc!
  def run_gc!
    @gc_runs ||= 0
    @gc_runs += 1
    old_run_gc!
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

  def test_process_restart
    @handler.stubs(:when_ready).returns(:restart)
    
    @handler.expects(:close_connection)
    @handler.expects(:restart!)
    @handler.process!
  end
  
  def test_process_exit
    @handler.stubs(:when_ready).returns(:exit)
    
    @handler.expects(:close_connection)
    @handler.process!
  end
  
  def test_process_breakpoint
    @handler.stubs(:when_ready).returns(:breakpoint)
    
    @handler.expects(:close_connection)
    @handler.expects(:breakpoint!)
    @handler.process!
  end
  
  def test_process_with_system_exit_exception
    @handler.stubs(:process_request).raises(SystemExit)
    
    @handler.expects(:dispatcher_log).with(:info, "terminated by explicit exit")
    @handler.process!
  end
  
  def test_restart_handler
    @handler.expects(:dispatcher_log).with(:info, "asked to restart ASAP")
    
    @handler.send(:restart_handler, nil)
    assert_equal :restart, @handler.when_ready
  end
  
  def test_breakpoint_handler
    @handler.expects(:dispatcher_log).with(:info, "asked to breakpoint ASAP")

    @handler.send(:breakpoint_handler, nil)
    assert_equal :breakpoint, @handler.when_ready
  end
  
  def test_install_signal_handler_should_log_on_bad_signal
    @handler.stubs(:trap).raises(ArgumentError)

    @handler.expects(:dispatcher_log).with(:warn, "Ignoring unsupported signal CHEESECAKE.")
    @handler.send(:install_signal_handler, "CHEESECAKE", nil)
  end
  
  def test_reload
    @handler.expects(:restore!)
    @handler.expects(:dispatcher_log).with(:info, "reloaded")

    @handler.send(:reload!)
    assert_nil @handler.when_ready
  end
  
  
  def test_reload_runs_gc_when_gc_request_period_set
    @handler.expects(:run_gc!)
    @handler.expects(:restore!)
    @handler.expects(:dispatcher_log).with(:info, "reloaded")
    @handler.gc_request_period = 10
    @handler.send(:reload!)
  end
  
  def test_reload_doesnt_run_gc_if_gc_request_period_isnt_set
    @handler.expects(:run_gc!).never
    @handler.expects(:restore!)
    @handler.expects(:dispatcher_log).with(:info, "reloaded")
    @handler.send(:reload!)
  end
  
  def test_restart!
    @handler.expects(:dispatcher_log).with(:info, "restarted")
    assert_equal true, @handler.send(:restart!), "Exec wasn't run"
  end
  
  def test_restore!
    $".expects(:replace)
    Dispatcher.expects(:reset_application!)
    ActionController::Routing::Routes.expects(:reload)
    @handler.send(:restore!)
  end

  def test_breakpoint!
    @handler.expects(:require).with('breakpoint')
    Breakpoint.expects(:activate_drb)
    @handler.expects(:breakpoint)
    @handler.expects(:dispatcher_log).with(:info, "breakpointing")
    @handler.send(:breakpoint!)
    assert_nil @handler.when_ready
  end
  
  def test_uninterrupted_processing
    @handler.process!
    assert_nil @handler.exit_code
    assert_nil @handler.when_ready
  end

  def test_interrupted_via_HUP_when_not_in_request
    @handler.expects(:reload!)
    FCGI.time_to_sleep = 1
    @handler.thread = Thread.new { @handler.process! }
    sleep 0.1 # let the thread get started
    @handler.send_signal("HUP")
    @handler.thread.join
    assert_nil @handler.exit_code
    assert_equal :reload, @handler.when_ready
  end

  def test_interrupted_via_HUP_when_in_request
    @handler.expects(:reload!)
    
    Dispatcher.time_to_sleep = 1
    @handler.thread = Thread.new { @handler.process! }
    sleep 0.1 # let the thread get started
    @handler.send_signal("HUP")
    @handler.thread.join
    assert_nil @handler.exit_code
    assert_equal :reload, @handler.when_ready
  end

  def test_interrupted_via_USR1_when_not_in_request
    FCGI.time_to_sleep = 1
    @handler.thread = Thread.new { @handler.process! }
    sleep 0.1 # let the thread get started
    @handler.send_signal("USR1")
    @handler.thread.join
    assert_nil @handler.exit_code
    assert_equal :exit, @handler.when_ready
  end

  def test_interrupted_via_USR1_when_in_request
    Dispatcher.time_to_sleep = 1
    @handler.thread = Thread.new { @handler.process! }
    sleep 0.1 # let the thread get started
    @handler.send_signal("USR1")
    @handler.thread.join
    assert_nil @handler.exit_code
    assert_equal :exit, @handler.when_ready
  end
  
  def test_interrupted_via_TERM
    Dispatcher.time_to_sleep = 1
    @handler.thread = Thread.new { @handler.process! }
    sleep 0.1 # let the thread get started
    @handler.send_signal("TERM")
    @handler.thread.join
    assert_equal 0, @handler.exit_code
    assert_nil @handler.when_ready
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
          assert_match %r{^killed}, @log.string
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
          assert_match %r{^killed}, @log.string
      end
    end
  end
end

class RailsFCGIHandlerPeriodicGCTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
    FCGI.time_to_sleep = nil
    FCGI.raise_exception = nil
    FCGI.each_cgi_count = nil
    Dispatcher.time_to_sleep = nil
    Dispatcher.raise_exception = nil
    Dispatcher.dispatch_hook = nil
  end

  def teardown
    FCGI.each_cgi_count = nil
    Dispatcher.dispatch_hook = nil
    GC.enable
  end

  def test_normal_gc
    @handler = RailsFCGIHandler.new(@log)
    assert_nil @handler.gc_request_period

    # When GC is enabled, GC.disable disables and returns false.
    assert_equal false, GC.disable
  end

  def test_periodic_gc
    Dispatcher.dispatch_hook = lambda do |cgi|
      # When GC is disabled, GC.enable enables and returns true.
      assert_equal true, GC.enable
      GC.disable
    end

    @handler = RailsFCGIHandler.new(@log, 10)
    assert_equal 10, @handler.gc_request_period
    FCGI.each_cgi_count = 1
    @handler.process!
    assert_equal 1, @handler.gc_runs

    FCGI.each_cgi_count = 10
    @handler.process!
    assert_equal 3, @handler.gc_runs

    FCGI.each_cgi_count = 25
    @handler.process!
    assert_equal 6, @handler.gc_runs

    assert_nil @handler.exit_code
    assert_nil @handler.when_ready
  end
end

rescue LoadError
  $stderr.puts "Skipping dispatcher tests. `gem install mocha` and try again."
end