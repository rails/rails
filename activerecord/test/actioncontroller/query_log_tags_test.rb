# frozen_string_literal: true

require "cases/helper"
require "action_controller"
require "active_record/railties/query_log_tags"
require "models/dashboard"

class DashboardController < ActionController::Base
  def index
    @dashboard = Dashboard.first
    render body: nil
  end
end

class DashboardApiController < ActionController::API
  def index
    render json: Dashboard.all
  end
end

# This config var is added in the railtie
class ActionController::Base
  mattr_accessor :query_log_tags_action_filter_enabled, instance_accessor: false, default: true
end

ActionController::Base.include(ActiveRecord::Railties::QueryLogTags::ActionController)
ActionController::API.include(ActiveRecord::Railties::QueryLogTags::ActionController)

class ActionControllerQueryLogTagsTest < ActiveRecord::TestCase
  def setup
    @env = Rack::MockRequest.env_for("/")
    @default_components = log_tag_context.components = [:application, :controller, :action]
    @original_enabled = ActiveRecord::Base.query_log_tags_enabled
    if @original_enabled == false
      # if we haven't enabled the feature, the execution methods need to be prepended at run time
      ActiveRecord::Base.connection.class_eval do
        prepend(ActiveRecord::ConnectionAdapters::QueryLogTags::ExecutionMethods)
      end
    end
    ActiveRecord::Base.query_log_tags_enabled = true
    @original_application_name = log_tag_context.send(:context)[:application_name]
    log_tag_context.update(application_name: "active_record")
  end

  def teardown
    log_tag_context.components = []
    ActiveRecord::Base.query_log_tags_enabled = @original_enabled
    log_tag_context.update(application_name: @original_application_name)
  end

  def log_tag_context
    ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext
  end

  def test_default_components_are_added_to_comment
    assert_sql(%r{/\*application:active_record,controller:dashboard,action:index\*/}) do
      DashboardController.action(:index).call(@env)
    end
  end

  def test_configuring_query_log_tags_components
    log_tag_context.components = [:controller]

    assert_sql(%r{/\*controller:dashboard\*/}) do
      DashboardController.action(:index).call(@env)
    end
  ensure
    log_tag_context.components = @default_components
  end

  def test_api_controller_includes_comments
    log_tag_context.components = [:controller]

    assert_sql(%r{/\*controller:dashboard_api\*/}) do
      DashboardApiController.action(:index).call(@env)
    end
  ensure
    log_tag_context.components = @default_components
  end
end
