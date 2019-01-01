# frozen_string_literal: true

require "active_support/concern"

module ActiveSupport
  # Actionable errors let's you define actions to resolve an error.
  #
  # To make an error actionable, include the <tt>ActiveSupport::ActionableError</tt>
  # module and invoke the +action+ class macro to define the action. An action
  # needs a name and a block to execute.
  module ActionableError
    extend Concern

    NonActionable = Class.new(StandardError)

    NoActions = Hash.new do |_, name| # :nodoc:
      raise NonActionable, "Cannot find action \"#{name}\""
    end

    included do
      class_attribute :_actions, default: NoActions.dup
    end

    def self.actions(error) # :nodoc:
      case error
      when ActionableError, -> it { Class === it && it < ActionableError }
        error._actions
      else
        NoActions
      end
    end

    def self.dispatch(error, name) # :nodoc:
      actions(error.is_a?(String) ? error.constantize : error)[name].call
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
      def action(name, &block)
        _actions[name] = block
      end
    end
  end
end
