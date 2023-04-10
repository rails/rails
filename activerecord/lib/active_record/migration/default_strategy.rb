# frozen_string_literal: true

module ActiveRecord
  class Migration
    # The default strategy for executing migrations. Delegates method calls
    # to the connection adapter.
    class DefaultStrategy < ExecutionStrategy # :nodoc:
      private
        def method_missing(method, *arguments, &block)
          connection.send(method, *arguments, &block)
        end
        ruby2_keywords(:method_missing)

        def respond_to_missing?(method, *)
          connection.respond_to?(method) || super
        end

        def connection
          migration.connection
        end
    end
  end
end
