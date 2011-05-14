require 'active_record_unit'
require 'active_record/railties/controller_runtime'
require 'fixtures/project'
require 'active_support/log_subscriber/test_helper'
require 'action_controller/log_subscriber'

ActionController::Base.send :include, ActiveRecord::Railties::ControllerRuntime

class ControllerRuntimeLogSubscriberTest < ActionController::TestCase
  class LogSubscriberController < ActionController::Base
    def show
      render :inline => "<%= Project.all %>"
    end

    def zero
      render :inline => "Zero DB runtime"
    end
  end

  include ActiveSupport::LogSubscriber::TestHelper
  tests LogSubscriberController

  def setup
    super
    @old_logger = ActionController::Base.logger
    ActionController::LogSubscriber.attach_to :action_controller
  end

  def teardown
    super
    ActiveSupport::LogSubscriber.log_subscribers.clear
    ActionController::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_log_with_active_record
    get :show
    wait

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: [\d.]+ms\)/, @logger.logged(:info)[1])
  end

  def test_runtime_reset_before_requests
    ActiveRecord::LogSubscriber.runtime += 12345
    get :zero
    wait

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: 0.0ms\)/, @logger.logged(:info)[1])
  end
end
