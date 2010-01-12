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
  end
end

module ActionControllerSubscriberTest
  Rails::Subscriber.add(:action_controller, ActionController::Railties::Subscriber.new)

  def self.included(base)
    base.tests Another::SubscribersController
  end

  def wait
    sleep(0.01)
    super
  end

  def setup
    @old_logger = ActionController::Base.logger
    super
  end

  def teardown
    super
    ActionController::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_process_action
    get :show
    wait
    assert_equal 3, @logger.logged(:info).size
    assert_match /Processed\sAnother::SubscribersController#show/, @logger.logged(:info)[0]
  end

  def test_process_action_without_parameters
    get :show
    wait
    assert_nil @logger.logged(:info).detect {|l| l =~ /Parameters/ }
  end

  def test_process_action_with_parameters
    get :show, :id => '10'
    wait

    assert_equal 4, @logger.logged(:info).size
    assert_equal 'Parameters: {"id"=>"10"}', @logger.logged(:info)[1]
  end

  def test_process_action_with_view_runtime
    get :show
    wait
    assert_match /View runtime/, @logger.logged(:info)[1]
  end

  def test_process_action_with_status_and_request_uri
    get :show
    wait
    last = @logger.logged(:info).last
    assert_match /Completed/, last
    assert_match /200/, last
    assert_match /another\/subscribers\/show/, last
  end

  def test_process_action_with_filter_parameters
    Another::SubscribersController.filter_parameter_logging(:lifo, :amount)

    get :show, :lifo => 'Pratik', :amount => '420', :step => '1'
    wait

    params = @logger.logged(:info)[1]
    assert_match /"amount"=>"\[FILTERED\]"/, params
    assert_match /"lifo"=>"\[FILTERED\]"/, params
    assert_match /"step"=>"1"/, params
  end

  def test_redirect_to
    get :redirector
    wait

    assert_equal 3, @logger.logged(:info).size
    assert_equal "Redirected to http://foo.bar/ with status 302", @logger.logged(:info)[0]
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
