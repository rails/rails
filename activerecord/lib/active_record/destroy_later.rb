# frozen_string_literal: true

module ActiveRecord
  module DestroyLater
    extend ActiveSupport::Concern

    ACTIVE_JOB_ERROR_MESSAGE = "ActiveJob is required to use the destroy later function"

    module ClassMethods
      # Automatically destroy records after a specified amount of time.
      #
      #   class Export < ApplicationRecord
      #     # Destroy all exports 30 days after creation
      #     destroy_later after: 30.days
      #
      #     # Destroy exports 30 days after completing them
      #     destroy_later after: 30.days, if: -> { status_previously_changed? && completed? }
      #   end
      #
      # It adds an +after_commit+ callback that schedules an +ActiveRecord::DestroyJob+.
      #
      # Optionally pass the duration to wait in +after:+. If no value is passed, the records will
      # be destroyed as soon as the queuing system is free.
      #
      # Optionally pass the name of an instance method in +ensuring:+. If the given method returns false at the
      # scheduled destroy time, the record will not be destroyed.
      #
      #   # Destroy exports 30 days after completing them, ensuring they're still marked as completed at destroy time
      #   class Export < ApplicationRecord
      #     destroy_later after: 30.days, if: -> { status_previously_changed? && completed? }, ensuring: :completed?
      #   end
      def destroy_later(after: nil, if: nil, ensuring: nil)
        if !destroy_later_job
          raise ActiveRecord::ActiveJobRequiredError, ACTIVE_JOB_ERROR_MESSAGE
        end

        option_if = binding.local_variable_get(:if)

        after_commit -> { destroy_later after: after, ensuring: ensuring },
          on: option_if ? %i[ create update ] : :create, if: option_if
      end
    end

    # Schedules a record to be destroyed after a specified amount of time.
    # If no time is specified, the records will be destroyed as soon as the queuing system is free.
    #
    # Optionally pass the name of an instance method in +ensuring:+. If the given method returns false at the
    # scheduled destroy time, the record will not be destroyed.
    def destroy_later(after: nil, ensuring: nil)
      unless destroy_later_job
        raise ActiveRecord::ActiveJobRequiredError, ACTIVE_JOB_ERROR_MESSAGE
      end

      destroy_later_job.set(wait: after).perform_later(self, ensuring: ensuring)
    end
  end
end
