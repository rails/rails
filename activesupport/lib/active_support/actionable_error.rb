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

    included do
      class_attribute :_actions, default: Hash.new do |_, label|
        raise NonActionable, "Cannot find action \"#{label}\" for #{self}"
      end
    end

    def self.===(other) # :nodoc:
      super || Module === other && other.ancestors.include?(self)
    end

    def self.actions(error) # :nodoc:
      error = error.constantize if String === error
      raise NonActionable, "#{error.name} is non-actionable" unless self === error
      error._actions
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
