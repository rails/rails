require "abstract_unit"
require "rails/subscriber/test_helper"
require "action_controller/railties/subscriber"

module Another
  class SubscribersController < ActionController::Base
    def show
      render :nothing => true
    end

    def redirector
      redirect_to "http://foo.bar/"
    end

    def data_sender
      send_data "cool data", :filename => "omg.txt"
    end

    def xfile_sender
      send_file File.expand_path("company.rb", FIXTURE_LOAD_PATH), :x_sendfile => true
    end

    def file_sender
      send_file File.expand_path("company.rb", FIXTURE_LOAD_PATH)
    end

    def with_fragment_cache
      render :inline => "<%= cache('foo'){ 'bar' } %>"
    end

    def with_page_cache
      cache_page("Super soaker", "/index.html")
      render :nothing => true
    end
  end
end

module ActionControllerSubscriberTest

  def self.included(base)
    base.tests Another::SubscribersController
  end

  def setup
    @old_logger = ActionController::Base.logger

    @cache_path = File.expand_path('../temp/test_cache', File.dirname(__FILE__))
    ActionController::Base.page_cache_directory = @cache_path
    ActionController::Base.cache_store = :file_store, @cache_path

    Rails::Subscriber.add(:action_controller, ActionController::Railties::Subscriber.new)
    super
  end

  def teardown
    super
    Rails::Subscriber.subscribers.clear
    FileUtils.rm_rf(@cache_path)
    ActionController::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_process_action
    get :show
    wait
    assert_equal 2, logs.size
    assert_match /Processed\sAnother::SubscribersController#show/, logs[0]
  end

  def test_process_action_formats
    get :show
    wait
    assert_equal 2, logs.size
    assert_match /text\/html/, logs[0]
  end

  def test_process_action_without_parameters
    get :show
    wait
    assert_nil logs.detect {|l| l =~ /Parameters/ }
  end

  def test_process_action_with_parameters
    get :show, :id => '10'
    wait

    assert_equal 3, logs.size
    assert_equal 'Parameters: {"id"=>"10"}', logs[1]
  end

  def test_process_action_with_view_runtime
    get :show
    wait
    assert_match /\(Views: [\d\.]+ms\)/, logs[1]
  end

  def test_process_action_with_status_and_request_uri
    get :show
    wait
    last = logs.last
    assert_match /Completed/, last
    assert_match /200/, last
    assert_match /another\/subscribers\/show/, last
  end

  def test_process_action_with_filter_parameters
    Another::SubscribersController.filter_parameter_logging(:lifo, :amount)

    get :show, :lifo => 'Pratik', :amount => '420', :step => '1'
    wait

    params = logs[1]
    assert_match /"amount"=>"\[FILTERED\]"/, params
    assert_match /"lifo"=>"\[FILTERED\]"/, params
    assert_match /"step"=>"1"/, params
  end

  def test_redirect_to
    get :redirector
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to http://foo.bar/", logs[0]
  end

  def test_send_data
    get :data_sender
    wait

    assert_equal 3, logs.size
    assert_match /Sent data omg\.txt/, logs[0]
  end

  def test_send_file
    get :file_sender
    wait

    assert_equal 3, logs.size
    assert_match /Sent file/, logs[0]
    assert_match /test\/fixtures\/company\.rb/, logs[0]
  end

  def test_send_xfile
    get :xfile_sender
    wait

    assert_equal 3, logs.size
    assert_match /Sent X\-Sendfile header/, logs[0]
    assert_match /test\/fixtures\/company\.rb/, logs[0]
  end

  def test_with_fragment_cache
    ActionController::Base.perform_caching = true
    get :with_fragment_cache
    wait

    assert_equal 4, logs.size
    assert_match /Exist fragment\? views\/foo/, logs[0]
    assert_match /Write fragment views\/foo/, logs[1]
  ensure
    ActionController::Base.perform_caching = true
  end

  def test_with_page_cache
    ActionController::Base.perform_caching = true
    get :with_page_cache
    wait

    assert_equal 3, logs.size
    assert_match /Write page/, logs[0]
    assert_match /\/index\.html/, logs[0]
  ensure
    ActionController::Base.perform_caching = true
  end

  def logs
    @logs ||= @logger.logged(:info)
  end

  class SyncSubscriberTest < ActionController::TestCase
    include Rails::Subscriber::SyncTestHelper
    include ActionControllerSubscriberTest
  end

  class AsyncSubscriberTest < ActionController::TestCase
    include Rails::Subscriber::AsyncTestHelper
    include ActionControllerSubscriberTest
  end
end
