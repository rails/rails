module ActiveRecord
  class PredicateBuilder
    class BaseHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        predicate_builder.build(attribute, value.id)
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :predicate_builder
    end
  end
end
