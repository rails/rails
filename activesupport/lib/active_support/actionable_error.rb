# frozen_string_literal: true

require "active_support/concern"

module ActiveSupport
  # Actionable errors let's you define actions to resolve an error.
  #
  # To make an error actionable, include the <tt>ActiveSupport::ActionableError</tt>
  # module and invoke the +action+ class macro to define the action.
  #
  # An action needs a name and a procedure to execute. The name can be shown by
  # the action dispatching mechanism.
  module ActionableError
    extend Concern

    NonActionable = Class.new(StandardError)

    NoActions = Hash.new do |_, label| # :nodoc:
      raise NonActionable, "Cannot find action \"#{label}\" for #{self}"
    end

    included do
      class_attribute :_actions, default: NoActions.dup
    end

    def self.actions(error) # :nodoc:
      case error
      when String
        actions(error.constantize)
      when ActionableError, -> it { Class === it && it < ActionableError }
        error._actions
      when Exception
        NoActions
      else
        raise NonActionable, "#{error} is non-actionable"
      end
    end

    def self.dispatch(error, label) # :nodoc:
      actions(error)[label].call
    end

    module ClassMethods
      # Defines an action that can resolve the error.
      #
      #   class PendingMigrationError < MigrationError
      #     include ActiveSupport::ActionableError
      #
      #     action "Run pending migrations" do
      #       ActiveRecord::Tasks::DatabaseTasks.migrate
      #     end
      #   end
      def action(label, &block)
        _actions[label] = block
      end
    end
  end
end
