require 'active_record_unit'
require 'active_record/railties/controller_runtime'
require 'fixtures/project'
require 'rails/subscriber/test_helper'
require 'action_controller/railties/subscriber'

ActionController::Base.send :include, ActiveRecord::Railties::ControllerRuntime

module ControllerRuntimeSubscriberTest
  class SubscriberController < ActionController::Base
    def show
      render :inline => "<%= Project.all %>"
    end
  end

  def self.included(base)
    base.tests SubscriberController
  end

  def setup
    @old_logger = ActionController::Base.logger
    Rails::Subscriber.add(:action_controller, ActionController::Railties::Subscriber.new)
    super
  end

  def teardown
    super
    Rails::Subscriber.subscribers.clear
    ActionController::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end
 
  def test_log_with_active_record
    get :show
    wait

    assert_equal 1, @logger.logged(:info).size
    assert_match /\(Views: [\d\.]+ms | ActiveRecord: [\d\.]+ms\)/, @logger.logged(:info)[0]
  end

  class SyncSubscriberTest < ActionController::TestCase
    include Rails::Subscriber::SyncTestHelper
    include ControllerRuntimeSubscriberTest
  end

  class AsyncSubscriberTest < ActionController::TestCase
    include Rails::Subscriber::AsyncTestHelper
    include ControllerRuntimeSubscriberTest
  end
end