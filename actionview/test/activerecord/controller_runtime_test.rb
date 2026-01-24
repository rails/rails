# frozen_string_literal: true

require "active_record_unit"
require "active_record/railties/controller_runtime"
require "fixtures/project"
require "active_support/log_subscriber/test_helper"
require "action_controller/structured_event_subscriber"
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
      ActiveRecord::RuntimeRegistry.stats.sql_runtime += 100.0
      Project.last
      redirect_to "/"
    end

    def redirect
      Project.all
      redirect_to action: "show"
    end

    def db_after_render
      render inline: "Hello world"
      Project.all.to_a
      ActiveRecord::RuntimeRegistry.stats.sql_runtime += 100.0
    end
  end

  tests LogSubscriberController

  with_routes do
    get :show, to: "#{LogSubscriberController.controller_path}#show"
    get :zero, to: "#{LogSubscriberController.controller_path}#zero"
    get :db_after_render, to: "#{LogSubscriberController.controller_path}#db_after_render"
    get :redirect, to: "#{LogSubscriberController.controller_path}#redirect"
    post :create, to: "#{LogSubscriberController.controller_path}#create"
  end

  def run(*)
    with_debug_event_reporting do
      super
    end
  end

  def setup
    super
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @old_logger = ActionController::LogSubscriber.logger
    ActionController::LogSubscriber.logger = @logger
  end

  def teardown
    super
    ActionController::LogSubscriber.logger = @old_logger
  end

  def test_log_with_active_record
    get :show

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: [\d.]+ms \(0 queries, 0 cached\) \| GC: [\d.]+ms\)/, @logger.logged(:info)[1])
  end

  def test_runtime_reset_before_requests
    ActiveRecord::RuntimeRegistry.stats.sql_runtime += 12345.0
    get :zero

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: [\d.]+ms \(0 queries, 0 cached\) \| GC: [\d.]+ms\)/, @logger.logged(:info)[1])
  end

  def test_log_with_active_record_when_post
    post :create

    assert_match(/ActiveRecord: ([1-9][\d.]+)ms \(1 query, 0 cached\) \| GC: [\d.]+ms\)/, @logger.logged(:info)[2])
  end

  def test_log_with_active_record_when_redirecting
    get :redirect

    assert_equal 3, @logger.logged(:info).size
    assert_match(/\(ActiveRecord: [\d.]+ms \(0 queries, 0 cached\) \| GC: [\d.]+ms\)/, @logger.logged(:info)[2])
  end

  def test_include_time_query_time_after_rendering
    get :db_after_render

    assert_equal 2, @logger.logged(:info).size
    assert_match(/\(Views: [\d.]+ms \| ActiveRecord: ([1-9][\d.]+)ms \(1 query, 0 cached\) \| GC: [\d.]+ms\)/, @logger.logged(:info)[1])
  end
end
