require 'abstract_unit'
require 'stringio'
require 'logger'

class FailsafeTest < ActionController::TestCase
  FIXTURE_PUBLIC = "#{File.dirname(__FILE__)}/../fixtures/failsafe".freeze
  
  def setup
    @old_error_file_path = ActionController::Failsafe.error_file_path
    ActionController::Failsafe.error_file_path = FIXTURE_PUBLIC
    @app = mock
    @log_io = StringIO.new
    @logger = Logger.new(@log_io)
    @failsafe = ActionController::Failsafe.new(@app)
    @failsafe.stubs(:failsafe_logger).returns(@logger)
  end
  
  def teardown
    ActionController::Failsafe.error_file_path = @old_error_file_path
  end
  
  def app_will_raise_error!
    @app.expects(:call).then.raises(RuntimeError.new("Printer on fire"))
  end
  
  def test_calls_app_and_returns_its_return_value
    @app.expects(:call).returns([200, { "Content-Type" => "text/html" }, "ok"])
    assert_equal [200, { "Content-Type" => "text/html" }, "ok"], @failsafe.call({})
  end
  
  def test_writes_to_log_file_on_exception
    app_will_raise_error!
    @failsafe.call({})
    assert_match /Printer on fire/, @log_io.string     # Logs exception message.
    assert_match /failsafe_test\.rb/, @log_io.string   # Logs backtrace.
  end
  
  def test_returns_500_internal_server_error_on_exception
    app_will_raise_error!
    response = @failsafe.call({})
    assert_equal 3, response.size    # It is a valid Rack response.
    assert_equal 500, response[0]    # Status is 500.
  end
  
  def test_renders_error_page_file_with_erb
    app_will_raise_error!
    response = @failsafe.call({})
    assert_equal 500, response[0]
    assert_equal "hello my world", response[2].join
  end
  
  def test_returns_a_default_message_if_erb_rendering_failed
    app_will_raise_error!
    @failsafe.expects(:render_template).raises(RuntimeError.new("Harddisk is crashing"))
    response = @failsafe.call({})
    assert_equal 500, response[0]
    assert_match /500 Internal Server Error/, response[2].join
    assert_match %r(please read this web application's log file), response[2].join
  end
end
