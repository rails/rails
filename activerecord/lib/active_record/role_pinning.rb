# frozen_string_literal: true

module ActiveRecord
  # Implements write-triggered role pinning within an executor scope.
  #
  # Pinning is enabled per request/job by executor hooks. Once enabled, every
  # write can set or extend a pin window so subsequent checkouts use the writing
  # role and avoid stale replica reads.
  module RolePinning
    PINNING_ENABLED_KEY = :active_record_role_pinning_enabled
    PINNED_UNTIL_KEY = :active_record_role_pinned_until

    module ExecutorHooks
      # Enables role pinning for the current executor scope.
      #
      # @return [Boolean, nil] +true+ when enabled, +nil+ when disabled by config.
      # @example
      #   ActiveRecord.pin_role_on_write = 2
      #   ActiveRecord::RolePinning::ExecutorHooks.run # => true
      def self.run
        return unless ActiveRecord.pin_role_on_write

        ActiveSupport::IsolatedExecutionState[RolePinning::PINNING_ENABLED_KEY] = true
        true
      end

      # Clears role pinning state for the current executor scope.
      #
      # @param was_enabled [Boolean, nil] the value returned by +run+ for this scope.
      # @return [void]
      # @example
      #   ActiveRecord::RolePinning::ExecutorHooks.complete(true)
      def self.complete(was_enabled)
        return unless was_enabled

        ActiveSupport::IsolatedExecutionState[RolePinning::PINNING_ENABLED_KEY] = nil
        ActiveSupport::IsolatedExecutionState[RolePinning::PINNED_UNTIL_KEY] = nil
      end
    end

    # Registers role pinning hooks into an executor.
    #
    # @param executor [ActiveSupport::Executor] the executor to register hooks on.
    # @return [void]
    # @example
    #   ActiveRecord::RolePinning.install_executor_hooks
    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(ExecutorHooks)
    end

    # Returns whether a write pin is currently active.
    #
    # A +:permanent+ pin remains active for the whole executor scope. Time-based
    # pins are compared using +Process::CLOCK_MONOTONIC+ and are cleared once
    # expired.
    #
    # @return [Boolean] +true+ if pinned, otherwise +false+.
    # @example
    #   ActiveRecord::RolePinning.pinned? # => false
    def self.pinned?
      pinned_until = ActiveSupport::IsolatedExecutionState[PINNED_UNTIL_KEY]
      return false unless pinned_until
      return true if pinned_until == :permanent

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) < pinned_until
        true
      else
        ActiveSupport::IsolatedExecutionState[PINNED_UNTIL_KEY] = nil
        false
      end
    end

    # Records a write and sets/extends the pin window for this scope.
    #
    # When +ActiveRecord.pin_role_on_write+ is +true+, the pin is permanent for
    # the current executor scope. Otherwise it is treated as a numeric duration
    # in seconds and added to the monotonic clock.
    #
    # @return [void]
    # @example
    #   ActiveRecord.pin_role_on_write = 2.seconds
    #   ActiveRecord::RolePinning.pin!
    def self.pin!
      return unless ActiveSupport::IsolatedExecutionState[PINNING_ENABLED_KEY]

      duration = ActiveRecord.pin_role_on_write
      ActiveSupport::IsolatedExecutionState[PINNED_UNTIL_KEY] =
        if duration == true
          :permanent
        else
          Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration.to_f
        end
    end
  end
end
