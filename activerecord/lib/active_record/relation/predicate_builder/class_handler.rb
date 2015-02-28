module ActiveRecord
  class PredicateBuilder
    class ClassHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        print_deprecation_warning
        predicate_builder.build(attribute, value.name)
      end

      protected

      attr_reader :predicate_builder

      private

      def print_deprecation_warning
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Passing a class as a value in an Active Record query is deprecated and
          will be removed. Pass a string instead.
        MSG
      end
    end
  end
end
