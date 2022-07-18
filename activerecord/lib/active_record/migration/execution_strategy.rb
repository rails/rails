# frozen_string_literal: true

module ActiveRecord
  class Migration
    # ExecutionStrategy is used by the migration to respond to any method calls
    # that the migration class does not implement directly. This is the base strategy.
    # All strategies should inherit from this class.
    #
    # The ExecutionStrategy receives the current +migration+ when initialized.
    class ExecutionStrategy # :nodoc:
      def initialize(migration)
        @migration = migration
      end

      private
        attr_reader :migration
    end
  end
end
