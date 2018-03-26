# frozen_string_literal: true

module ActiveJob
  # Provides a helper to define which classes Active Job should try to preserve
  # its attributes before the job gets executed.
  module RestoreAttributes
    extend ActiveSupport::Concern

    included do
      mattr_accessor :shared_attributes_classes
    end

    module ClassMethods
      # Specify classes that this job should preserve their attributes when
      # enqueuing the job and restoring them upon the job execution. The given
      # classes can be a descendant of <tt>ActiveSupport::CurrentAttributes</tt>
      # or any class that respond to +attributes+ and +attributes=+.
      def restore_attributes_on(*klasses)
        self.shared_attributes_classes = klasses
      end
    end
  end
end
