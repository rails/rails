require 'abstract_unit'

module Another
  class LoggingController < ActionController::Base
    layout "layouts/standard"

    def show
      render :nothing => true
    end

    def with_layout
      render :template => "test/hello_world", :layout => true
    end
  end
end

class LoggingTest < ActionController::TestCase
  tests Another::LoggingController

  def setup
    super
    set_logger
  end

  def get(*args)
    super
    wait
  end

  def wait
    ActiveSupport::Notifications.notifier.wait
  end

  def test_logging_without_parameters
    get :show
    assert_equal 4, logs.size
    assert_nil logs.detect {|l| l =~ /Parameters/ }
  end

  def test_logging_with_parameters
    get :show, :id => '10'
    assert_equal 5, logs.size

    params = logs.detect {|l| l =~ /Parameters/ }
    assert_equal 'Parameters: {"id"=>"10"}', params
  end

  def test_log_controller_with_namespace_and_action
    get :show
    assert_match /Processed\sAnother::LoggingController#show/, logs[1]
  end

  def test_log_view_runtime
     get :show
     assert_match /View runtime/, logs[2]
   end

  def test_log_completed_status_and_request_uri
    get :show
    last = logs.last
    assert_match /Completed/, last
    assert_match /200/, last
    assert_match /another\/logging\/show/, last
  end

  def test_logger_prints_layout_and_template_rendering_info
    get :with_layout
    logged = logs.find {|l| l =~ /render/i }
    assert_match /Rendered (.*)test\/hello_world.erb within (.*)layouts\/standard.html.erb/, logged
  end

  private
    def set_logger
      @controller.logger = MockLogger.new
    end

    def logs
      @logs ||= @controller.logger.logged.compact.map {|l| l.to_s.strip}
    end
end
