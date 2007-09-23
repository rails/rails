require File.dirname(__FILE__) + "/abstract_unit"

uses_mocha 'fcgi dispatcher tests' do

require 'fcgi_handler'

module ActionController; module Routing; module Routes; end end end

class RailsFCGIHandlerTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
    @handler = RailsFCGIHandler.new(@log)
  end

  def test_process_restart
    cgi = mock
    FCGI.stubs(:each_cgi).yields(cgi)

    @handler.expects(:process_request).once
    @handler.expects(:dispatcher_error).never

    @handler.expects(:when_ready).returns(:restart)
    @handler.expects(:close_connection).with(cgi)
    @handler.expects(:reload!).never
    @handler.expects(:restart!)

    @handler.process!
  end

  def test_process_exit
    cgi = mock
    FCGI.stubs(:each_cgi).yields(cgi)

    @handler.expects(:process_request).once
    @handler.expects(:dispatcher_error).never

    @handler.expects(:when_ready).returns(:exit)
    @handler.expects(:close_connection).with(cgi)
    @handler.expects(:reload!).never
    @handler.expects(:restart!).never

    @handler.process!
  end

  def test_process_with_system_exit_exception
    cgi = mock
    FCGI.stubs(:each_cgi).yields(cgi)

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

  def test_restart_handler
    @handler.expects(:dispatcher_log).with(:info, "asked to restart ASAP")

    @handler.send(:restart_handler, nil)
    assert_equal :restart, @handler.when_ready
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
    cgi = mock
    FCGI.expects(:each_cgi).yields(cgi)
    @handler.expects(:process_request).with(cgi)

    @handler.process!

    assert_nil @handler.when_ready
  end
end


class RailsFCGIHandlerSignalsTest < Test::Unit::TestCase
  def setup
    @log = StringIO.new
    @handler = RailsFCGIHandler.new(@log)
  end

  def test_interrupted_via_HUP_when_not_in_request
    cgi = mock
    FCGI.expects(:each_cgi).once.yields(cgi)
    @handler.expects(:gc_countdown).returns { Process.kill 'HUP', $$ }

    @handler.expects(:reload!).once
    @handler.expects(:close_connection).never
    @handler.expects(:exit).never

    @handler.process!
    assert_equal :reload, @handler.when_ready
  end

  def test_interrupted_via_HUP_when_in_request
    cgi = mock
    FCGI.expects(:each_cgi).once.yields(cgi)
    Dispatcher.expects(:dispatch).with(cgi).returns { Process.kill 'HUP', $$ }

    @handler.expects(:reload!).once
    @handler.expects(:close_connection).never
    @handler.expects(:exit).never

    @handler.process!
    assert_equal :reload, @handler.when_ready
  end

  def test_interrupted_via_USR1_when_not_in_request
    cgi = mock
    FCGI.expects(:each_cgi).once.yields(cgi)
    @handler.expects(:gc_countdown).returns { Process.kill 'USR1', $$ }
    @handler.expects(:exit_handler).never

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).with(cgi).once
    @handler.expects(:exit).never

    @handler.process!
    assert_nil @handler.when_ready
  end

  def test_interrupted_via_USR1_when_in_request
    cgi = mock
    FCGI.expects(:each_cgi).once.yields(cgi)
    Dispatcher.expects(:dispatch).with(cgi).returns { Process.kill 'USR1', $$ }

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).with(cgi).once
    @handler.expects(:exit).never

    @handler.process!
    assert_equal :exit, @handler.when_ready
  end

  def test_interrupted_via_TERM
    cgi = mock
    FCGI.expects(:each_cgi).once.yields(cgi)
    Dispatcher.expects(:dispatch).with(cgi).returns { Process.kill 'TERM', $$ }

    @handler.expects(:reload!).never
    @handler.expects(:close_connection).never

    @handler.process!
    assert_nil @handler.when_ready
  end

  def test_runtime_exception_in_fcgi
    error = RuntimeError.new('foo')
    FCGI.expects(:each_cgi).times(2).raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^retrying/))
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^stopping/))
    @handler.process!
  end

  def test_runtime_error_in_dispatcher
    cgi = mock
    error = RuntimeError.new('foo')
    FCGI.expects(:each_cgi).once.yields(cgi)
    Dispatcher.expects(:dispatch).once.with(cgi).raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^unhandled/))
    @handler.process!
  end

  def test_signal_exception_in_fcgi
    error = SignalException.new('USR2')
    FCGI.expects(:each_cgi).once.raises(error)
    @handler.expects(:dispatcher_error).with(error, regexp_matches(/^stopping/))
    @handler.process!
  end

  def test_signal_exception_in_dispatcher
    cgi = mock
    error = SignalException.new('USR2')
    FCGI.expects(:each_cgi).once.yields(cgi)
    Dispatcher.expects(:dispatch).once.with(cgi).raises(error)
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

    cgi = mock
    FCGI.expects(:each_cgi).times(10).yields(cgi)
    Dispatcher.expects(:dispatch).times(10).with(cgi)

    @handler.expects(:run_gc!).never
    9.times { @handler.process! }
    @handler.expects(:run_gc!).once
    @handler.process!

    assert_nil @handler.when_ready
  end
end

end # uses_mocha
