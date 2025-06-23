# frozen_string_literal: true

module ActiveRecord
  # = Active Record No Touching
  module NoTouching
    extend ActiveSupport::Concern

    module ClassMethods
      # Lets you selectively disable calls to +touch+ for the
      # duration of a block.
      #
      # ==== Examples
      #   ActiveRecord::Base.no_touching do
      #     Project.first.touch  # does nothing
      #     Message.first.touch  # does nothing
      #   end
      #
      #   Project.no_touching do
      #     Project.first.touch  # does nothing
      #     Message.first.touch  # works, but does not touch the associated project
      #   end
      #
      def no_touching(&block)
        NoTouching.apply_to(self, &block)
      end
      alias_method :cant_touch_this, :no_touching
    end

    class << self
      def apply_to(klass) # :nodoc:
        klasses.push(klass)
        yield
      ensure
        klasses.pop
      end

      def applied_to?(klass) # :nodoc:
        klasses.any? { |k| k >= klass }
      end

      private
        def klasses
          ActiveSupport::IsolatedExecutionState[:active_record_no_touching_classes] ||= []
        end
    end

    # Returns +true+ if the class has +no_touching+ set, +false+ otherwise.
    #
    #   Project.no_touching do
    #     Project.first.no_touching? # true
    #     Message.first.no_touching? # false
    #   end
    #
    def no_touching?
      NoTouching.applied_to?(self.class)
    end

    def touch_later(*) # :nodoc:
      super unless no_touching?
    end

    def touch(*, **) # :nodoc:
      super unless no_touching?
    end
  end
end
