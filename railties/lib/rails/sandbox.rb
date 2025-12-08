# frozen_string_literal: true

module Rails
  # = Rails Sandbox
  #
  # Rails.sandbox provides a way to execute code in a transactional context
  # where all database changes are automatically rolled back at the end of
  # the block. This is useful for testing potentially destructive operations
  # safely.
  #
  # == Usage
  #
  #   result = Rails.sandbox do
  #     User.create!(name: "Test")
  #     User.count  # => 1
  #   end
  #   # User.count => 0 (rolled back)
  #   # result => 1 (return value preserved)
  #
  # == Environment Restriction
  #
  # Rails.sandbox is only available in development and test environments.
  # Attempting to use it in production will raise an error.
  #
  # == Extensibility
  #
  # Frameworks can register sandbox handlers via the Railtie DSL:
  #
  #   class MyFramework::Railtie < Rails::Railtie
  #     sandbox do |app, &block|
  #       # Wrap block in your framework's sandbox logic
  #       MyFramework.with_rollback(&block)
  #     end
  #   end
  #
  module Sandbox
    class << self
      def run(&block)
        raise_unless_local_env!
        raise_unless_initialized!

        handlers = collect_handlers

        if handlers.empty?
          yield
        else
          compose_handlers(handlers, block)
        end
      end

      private
        def raise_unless_local_env!
          unless Rails.env.local?
            raise "Rails.sandbox is only available in development and test environments"
          end
        end

        def raise_unless_initialized!
          unless Rails.application
            raise "Rails.sandbox requires a Rails application to be initialized"
          end
        end

        def collect_handlers
          Rails.application.railties.to_a
            .select { |r| r.class.respond_to?(:sandbox) }
            .flat_map { |r| r.class.sandbox }
        end

        # Compose handlers by nesting them around the original block.
        # Each handler wraps the next, with the innermost being the user's block.
        #
        # The `result` variable captures the return value of the original block,
        # regardless of what each handler returns. This ensures consistent
        # behavior even if a handler forgets to return the block's value.
        def compose_handlers(handlers, block)
          result = nil
          composed = -> { result = block.call }

          handlers.reverse_each do |handler|
            inner = composed
            composed = -> { handler.call(Rails.application, &inner) }
          end

          composed.call
          result
        end
    end
  end
end
