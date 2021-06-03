# frozen_string_literal: true

module ActiveRecord
  module Railties # :nodoc:
    module QueryLogTags #:nodoc:
      module ActionController
        extend ActiveSupport::Concern

        included do
          if ::ActionController::Base.query_log_tags_action_filter_enabled
            around_action :record_query_log_tags
          end
          ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.extend(ControllerContext)
        end

        def record_query_log_tags
          ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.update(controller: self)
          yield
        ensure
          ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.update(controller: nil)
        end

        module ControllerContext # :nodoc:
          def controller
            context[:controller]&.controller_name
          end

          def controller_with_namespace
            context[:controller]&.class&.name
          end

          def action
            context[:controller]&.action_name
          end
        end
      end

      module ActiveJob
        extend ActiveSupport::Concern

        included do
          if ::ActiveJob::Base.query_log_tags_action_filter_enabled
            ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.components << :job
            around_perform do |job, block|
              ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.update(job: job)
              block.call
            ensure
              ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.update(job: nil)
            end
          end
          ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext.extend(JobContext)
        end

        module JobContext
          def job
            context[:job]&.class&.name
          end
        end
      end
    end
  end
end
