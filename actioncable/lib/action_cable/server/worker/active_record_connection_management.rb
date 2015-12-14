module ActionCable
  module Server
    class Worker
      # Clear active connections between units of work so the long-running channel or connection processes do not hoard connections.
      module ActiveRecordConnectionManagement
        extend ActiveSupport::Concern

        included do
          if defined?(ActiveRecord::Base)
            set_callback :work, :around, :with_database_connections
          end
        end

        def with_database_connections
          connection.logger.tag(ActiveRecord::Base.logger) { yield }
        ensure
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end
  end
end