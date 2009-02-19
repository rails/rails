require 'abstract_unit'

uses_gem "fcgi", "0.8.7" do

require 'action_controller'
require 'fcgi_handler'

Dispatcher.middleware.clear

class RailsFCGIHandlerTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
    @handler = RailsFCGIHandler.new(@log)
  end

  def test_process_restart
    request = mock
    FCGI.stubs(:each).yields(request)

    @handler.expects(:process_request).once
    @handler.expects(:dispatcher_error).never

    @handler.expects(:when_ready).returns(:restart)
    @handler.expects(:close_connection).with(request)
    @handler.expects(:reload!).never
    @handler.expects(:restart!)

    @handler.process!
  end

  def test_process_exit
    request = mock
    FCGI.stubs(:each).yields(request)

    @handler.expects(:process_request).once
    @handler.expects(:dispatcher_error).never

    @handler.expects(:when_ready).returns(:exit)
    @handler.expects(:close_connection).with(request)
    @handler.expects(:reload!).never
    @handler.expects(:restart!).never

    @handler.process!
  end

  def test_process_with_system_exit_exception
    request = mock
    FCGI.stubs(:each).yields(request)

    @handler.expects(:process_request).once.raises(SystemExit)
    @handler.stubs(:dispatcher_log)
    @handler.expects(:dispatcher_log).with(:info, regexp_matches(/^stopping/))
    @handler.expects(:dispatcher_error).never

    @handler.expects(:when_ready).never
    @handler.expects(:close_connection).never
    @handler.expects(:reload!).never
    @handler.expects(:restart!).never

    @handler.process!
  end

  def test_restart_handler_outside_request
    @handler.expects(:dispatcher_log).with(:info, "asked to restart ASAP")
    @handler.expects(:restart!).once

    @handler.send(:restart_handler, nil)
    assert_equal nil, @handler.when_ready
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
    @handler.expects(:exec).returns('restarted')
    assert_equal 'restarted', @handler.send(:restart!)
  end

  def test_restore!
    $".expects(:replace)
    Dispatcher.expects(:reset_application!)
    ActionController::Routing::Routes.expects(:reload)
    @handler.send(:restore!)
  end

  def test_uninterrupted_processing
    request = mock
    FCGI.expects(:each).yields(request)
    @handler.expects(:process_request).with(request)

    @handler.process!

    assert_nil @handler.when_ready
  end
end


class RailsFCGIHandlerSignalsTest < Test::Unit::TestCase
  class ::RailsFCGIHandler
    attr_accessor :signal
    alias_method :old_gc_countdown, :gc_countdown
    def gc_countdown
      signal ? Process.kill(signal, $$) : old_gc_countdown
    end
  end

  def setup
    @log = StringIO.new
    @handler = RailsFCGIHandler.new(@log)
    @dispatcher = mock
    Dispatcher.stubs(:new).returns(@dispatcher)
  end

  def test_interrupted_via_HUP_when_not_in_request
    request = mock
    FCGI.expects(:each).once.yields(request)
    @handler.expects(:signal).times(2).returns('HUP')

    @handler.expects(:reload!).once
    @handler.expects(:close_connection).never
    @handler.expects(:exit).never

    @handler.process!
    assert_equal :reload, @handler.when_ready
  end

  def test_interrupted_via_USR1_when_not_in_request
    request = mock
    FCGI.expects(:each).once.yields(request)
    @handler.expects(:signal).times(2).returns('USR1')
    @handler.expects(:exit_handler).never

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).with(request).once
    @handler.expects(:exit).never

    @handler.process!
    assert_nil @handler.when_ready
  end

  def test_restart_via_USR2_when_in_request
    request = mock
    FCGI.expects(:each).once.yields(request)
    @handler.expects(:signal).times(2).returns('USR2')
    @handler.expects(:exit_handler).never

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).with(request).once
    @handler.expects(:exit).never
    @handler.expects(:restart!).once

    @handler.process!
    assert_equal :restart, @handler.when_ready
  end

  def test_interrupted_via_TERM
    request = mock
    FCGI.expects(:each).once.yields(request)
    ::Rack::Handler::FastCGI.expects(:serve).once.returns('TERM')

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).never

    @handler.process!
    assert_nil @handler.when_ready
  end

  def test_runtime_exception_in_fcgi
    error = RuntimeError.new('foo')
    FCGI.expects(:each).times(2).raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^retrying/))
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^stopping/))
    @handler.process!
  end

  def test_runtime_error_in_dispatcher
    request = mock
    error = RuntimeError.new('foo')
    FCGI.expects(:each).once.yields(request)
    ::Rack::Handler::FastCGI.expects(:serve).once.raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^unhandled/))
    @handler.process!
  end

  def test_signal_exception_in_fcgi
    error = SignalException.new('USR2')
    FCGI.expects(:each).once.raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^stopping/))
    @handler.process!
  end

  def test_signal_exception_in_dispatcher
    request = mock
    error = SignalException.new('USR2')
    FCGI.expects(:each).once.yields(request)
    ::Rack::Handler::FastCGI.expects(:serve).once.raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^stopping/))
    @handler.process!
  end
end


class RailsFCGIHandlerPeriodicGCTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
  end

  def teardown
    GC.enable
  end

  def test_normal_gc
    @handler = RailsFCGIHandler.new(@log)
    assert_nil @handler.gc_request_period

    # When GC is enabled, GC.disable disables and returns false.
    assert_equal false, GC.disable
  end

  def test_periodic_gc
    @handler = RailsFCGIHandler.new(@log, 10)
    assert_equal 10, @handler.gc_request_period

    request = mock
    FCGI.expects(:each).times(10).yields(request)

    @handler.expects(:run_gc!).never
    9.times { @handler.process! }
    @handler.expects(:run_gc!).once
    @handler.process!

    assert_nil @handler.when_ready
  end
end
end # uses_gem "fcgi"
