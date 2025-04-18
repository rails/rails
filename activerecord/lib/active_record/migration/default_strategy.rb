# frozen_string_literal: true

module ActiveRecord
  class Migration
    # The default strategy for executing migrations. Delegates method calls
    # to the connection adapter.
    class DefaultStrategy < ExecutionStrategy # :nodoc:
      private
        def method_missing(method, ...)
          connection.send(method, ...)
        end

        def respond_to_missing?(method, include_private = false)
          connection.respond_to?(method, include_private) || super
        end

        def connection
          migration.connection
        end
    end
  end
end
