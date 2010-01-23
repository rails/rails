require 'active_record_unit'
require 'active_record/railties/controller_runtime'
require 'fixtures/project'
require 'rails/subscriber/test_helper'
require 'action_controller/railties/subscriber'

ActionController::Base.send :include, ActiveRecord::Railties::ControllerRuntime

class ControllerRuntimeSubscriberTest < ActionController::TestCase
  class SubscriberController < ActionController::Base
    def show
      render :inline => "<%= Project.all %>"
    end
  end
  
  include Rails::Subscriber::TestHelper
  tests SubscriberController

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

    assert_equal 2, @logger.logged(:info).size
    assert_match /\(Views: [\d\.]+ms | ActiveRecord: [\d\.]+ms\)/, @logger.logged(:info)[1]
  end
end