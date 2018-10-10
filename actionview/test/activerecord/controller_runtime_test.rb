# frozen_string_literal: true

require "active_record_unit"
require "active_record/railties/controller_runtime"
require "fixtures/project"
require "active_support/log_subscriber/test_helper"
require "action_controller/log_subscriber"

ActionController::Base.include(ActiveRecord::Railties::ControllerRuntime)

class ControllerRuntimeLogSubscriberTest < ActionController::TestCase
  class LogSubscriberController < ActionController::Base
    def show
      render inline: "<%= Project.all %>"
    end

    def zero
      render inline: "Zero DB runtime"
    end

    def create
      ActiveRecord::LogSubscriber.runtime += 100
      Project.last
      redirect_to "/"
    end

    def redirect
      Project.all
      redirect_to action: "show"
    end

    def db_after_render
      render inline: "Hello world"
      Project.all
      ActiveRecord::LogSubscriber.runtime += 100
    end
  end

  include ActiveSupport::LogSubscriber::TestHelper
  tests LogSubscriberController

  with_routes do
    get :show, to: "#{LogSubscriberController.controller_path}#show"
    get :zero, to: "#{LogSubscriberController.controller_path}#zero"
    get :db_after_render, to: "#{LogSubscriberController.controller_path}#db_after_render"
    get :redirect, to: "#{LogSubscriberController.controller_path}#redirect"
    post :create, to: "#{LogSubscriberController.controller_path}#create"
  end

  def setup
    @old_logger = ActionController::Base.logger
    super
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
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: [\d.]+ms \| Allocations: [\d.]+\)/, @logger.logged(:info)[1])
  end

  def test_runtime_reset_before_requests
    ActiveRecord::LogSubscriber.runtime += 12345
    get :zero
    wait

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: [\d.]+ms \| Allocations: [\d.]+\)/, @logger.logged(:info)[1])
  end

  def test_log_with_active_record_when_post
    post :create
    wait
    assert_match(/ActiveRecord: ([1-9][\d.]+)ms \| Allocations: [\d.]+\)/, @logger.logged(:info)[2])
  end

  def test_log_with_active_record_when_redirecting
    get :redirect
    wait
    assert_equal 3, @logger.logged(:info).size
    assert_match(/\(ActiveRecord: [\d.]+ms \| Allocations: [\d.]+\)/, @logger.logged(:info)[2])
  end

  def test_include_time_query_time_after_rendering
    get :db_after_render
    wait

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: ([1-9][\d.]+)ms \| Allocations: [\d.]+\)/, @logger.logged(:info)[1])
  end
end
