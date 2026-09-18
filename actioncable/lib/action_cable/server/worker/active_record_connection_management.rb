# frozen_string_literal: true

# :markup: markdown

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

        def with_database_connections(&block)
          connection.logger.tag(ActiveRecord::Base.logger, &block)
        end
      end
    end
  end
end
