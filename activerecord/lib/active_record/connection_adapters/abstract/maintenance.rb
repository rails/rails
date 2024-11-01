# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # = Active Record Connection Adapter \Maintenance
    module Maintenance
      # Performs maintenance on the database given the type of event passed in.
      #
      # Rails supports the following events, but individual adapters may support only a subset:
      #
      # - +:analyze+: Triggered by `bin/rails db:maintenance:analyze`, this is intended to do
      #   ANALYZE operations that can be run frequently with minimal or no impact to a running
      #   application.
      #
      def perform_maintenance(event)
        raise NotImplementedError, "#{self.class} does not support maintenance"
      end
    end
  end
end
