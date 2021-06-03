# frozen_string_literal: true

require "activejob/helper"
require "active_record/railties/query_log_tags"
require "models/dashboard"

class DashboardJob < ActiveJob::Base
  def perform
    Dashboard.first
  end
end

# This config var is added in the railtie
class ActiveJob::Base
  mattr_accessor :query_log_tags_action_filter_enabled, instance_accessor: false, default: true
end

ActiveJob::Base.include(ActiveRecord::Railties::QueryLogTags::ActiveJob)

class ActiveJobQueryLogTagsTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  def setup
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
    log_tag_context.components = [:job]
  end

  def teardown
    ActiveRecord::Base.query_log_tags_enabled = @original_enabled
    log_tag_context.components = []
    log_tag_context.update(application_name: @original_application_name)
  end

  def log_tag_context
    ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext
  end

  def test_active_job
    assert_sql(%r{/\*job:DashboardJob\*/}) do
      DashboardJob.perform_later
      perform_enqueued_jobs
    end
  end
end
