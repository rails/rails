# frozen_string_literal: true

module ActiveSupport
  # Actionable errors let's you define actions to resolve an error.
  #
  # To make an error actionable, include the <tt>ActiveSupport::ActionableError</tt>
  # module and invoke the +action+ class macro to define the action. An action
  # needs a name and a block to execute.
  module ActionableError
    extend Concern

    class NonActionable < StandardError; end # :nodoc:

    Trigger = Struct.new(:actionable, :condition) do # :nodoc:
      def act_on(error)
        raise actionable if condition.call(error)
      end
    end

    class Definition # :nodoc:
      def self.build(&block)
        new(&block).build
      end

      def initialize(&block)
        instance_exec(self, &block)
      end

      def build
        actionable = self

        Class.new(StandardError) do
          include ActiveSupport::ActionableError

          # Call it here, so we trigger the missing message at definition time
          # and not the first time the error is raised.
          actionable_message = actionable.message

          define_method :initialize do |message = actionable_message|
            super(message)
          end

          actionable.actions.each do |(name, block)|
            action(name, &block)
          end

          trigger(actionable.trigger)
        end
      end


      def message(value = nil)
        if value
          @message = value
        else
          raise ArgumentError, <<~ERROR unless defined?(@message)
            A message should be provided for the definition of an actionable error.
          ERROR

          @message
        end
      end

      def trigger(value = nil)
        if value
          @trigger = value
        else
          raise ArgumentError, <<~ERROR unless defined?(@trigger)
            A trigger should be provided for the definition of an actionable error.
          ERROR

          @trigger
        end
      end

      def action(name, &block)
        @actions ||= []
        @actions << [name, block]
      end

      def actions
        raise ArgumentError, <<~ERROR unless defined?(@actions)
          At least one action should be provided for the definition of an actionable error.
        ERROR

        @actions
      end
    end

    mattr_accessor :triggers, default: Hash.new { |h, k| h[k] = [] } # :nodoc:

    included do
      class_attribute :_actions, default: {}
    end

    # Define an actionable error with a DSL.
    #
    # This can be useful if you're code does not depend strictly on Rails. In
    # this case, you may not want to define an error depending on Rails
    # specific code next to your regular error class hierarchy.
    #
    # You can define it the actionable error straight in a Railtie, next to you
    # Rails dependent code:
    #
    #  class ActiveStorage::Railtie < Rails::Engine
    #    initializer "active_storage.actionable_errors" do
    #      ActiveSupport::ActionableError.define :MissingInstallError, under: ActiveStorage do |actionable|
    #        actionable.message <<~END
    #          Action Mailbox does not appear to be installed. Do you want to install it now?
    #        END
    #
    #        actionable.trigger on: ActiveRecord::StatementInvalid, if: -> error do
    #          error.message.match?(InboundEmail.table_name)
    #        end
    #
    #        actionable.action "Install now" do
    #          Rails::Command.invoke("active_storage:install")
    #          Rails::Command.invoke("db:migrate")
    #        end
    #      end
    #    end
    #  end
    def self.define(name, under:, &block)
      under.const_set(name, Definition.build(&block))
    end

    def self.actions(error) # :nodoc:
      case error
      when ActionableError, -> it { Class === it && it < ActionableError }
        error._actions
      else
        {}
      end
    end

    def self.dispatch(error, name) # :nodoc:
      actions(error).fetch(name).call
    rescue KeyError
      raise NonActionable, "Cannot find action \"#{name}\""
    end

    def self.raise_if_triggered_by(error) # :nodoc:
      triggers[error.class].each { |trigger| trigger.act_on(error) }
      raise_if_triggered_by(error.cause) if error.cause
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

      # Trigger the current actionable error from a pre-existing if the
      # condition, given as a block, returns a truthy value.
      #
      #   class SetupError < Error
      #     include ActiveSupport::ActionableError
      #
      #     trigger on: ActiveRecord::RecordInvalid, if: -> error do
      #       error.message.match?(InboundEmail.table_name)
      #     end
      #   end
      #
      # Note: For an actionable error to be triggered, its constant needs to be
      # loaded. If it isn't autoloaded, the triggers won't be registered until
      # it is. Keep that in mind, if the actionable error isn't triggered.
      def trigger(on:, if:)
        ActiveSupport::ActionableError.triggers[on] << Trigger.new(self, binding.local_variable_get(:if))
      end
    end
  end
end
