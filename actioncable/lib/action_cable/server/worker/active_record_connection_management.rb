# frozen_string_literal: true

module ActionCable
  module Server
    class Worker
      module ActiveRecordConnectionManagement
        extend ActiveSupport::Concern

        included do
          if defined?(ActiveRecord::Base)
            set_callback :work, :around, :with_database_connections
          end
        end

        def with_database_connections
          connection.logger.tag(ActiveRecord::Base.logger) { yield }
        end
      end
    end
  end
end
