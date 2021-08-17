# frozen_string_literal: true

module ActionController
  module QueryTags # :nodoc:
    extend ActiveSupport::Concern

    included do
      around_action :expose_controller_to_query_logs
    end

    private
      def expose_controller_to_query_logs(&block)
        ActiveRecord::QueryLogs.set_context(controller: self, &block)
      end
  end
end
