# frozen_string_literal: true

module ActiveRecord
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
  # +destroy_later+ adds an +after_commit+ callback that schedules an ActiveRecord::DestroyJob. In the example above,
  # we use +completed_previously_changed?+ to check whether the record's +completed+ flag was changed in the preceding
  # save. (+completed_changed?+ wouldn't work because any prior changes to the record have been saved at the time the
  # condition is evaluated.)
  #
  # Optionally pass the name of an instance method in +ensuring:+. If the given method returns false at the
  # scheduled destroy time, the record will not be destroyed.
  #
  #   # Destroy exports 30 days after completing them, ensuring they're still marked as completed at destroy time
  #   class Export < ApplicationRecord
  #     destroy_later after: 30.days, if: -> { status_previously_changed? && completed? }, ensuring: :completed?
  #   end
  module DestroyLater
    extend ActiveSupport::Concern

    module ClassMethods
      def destroy_later(after:, if: nil, ensuring: nil)
        after_commit -> { destroy_later after: after, ensuring: ensuring },
          on: binding.local_variable_get(:if) ? %i[ create update ] : :create, if: binding.local_variable_get(:if)
      end
    end

    def destroy_later(after:, ensuring: nil)
      ActiveRecord::DestroyJob.set(wait: after).perform_later(self, ensuring: ensuring)
    end
  end
end
