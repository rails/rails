# frozen_string_literal: true

module ActiveSupport
  module Testing
    # Allows to configure the behavior when the test case has no assertions in it.
    # This is helpful in detecting broken tests that do not perform intended assertions.
    module AssertionlessTests # :nodoc:
      def self.prepended(klass)
        klass.class_attribute :_assertionless_tests_behavior, instance_accessor: false, instance_predicate: false
        klass.extend ClassMethods
        klass.assertionless_tests_behavior = :ignore
      end

      module ClassMethods
        def assertionless_tests_behavior
          _assertionless_tests_behavior
        end

        def assertionless_tests_behavior=(behavior)
          self._assertionless_tests_behavior =
            case behavior
            when :ignore, nil
              nil
            when :log
              logger =
                if defined?(Rails.logger) && Rails.logger
                  Rails.logger
                else
                  require "active_support/logger"
                  ActiveSupport::Logger.new($stderr)
                end

              ->(message) { logger.warn(message) }
            when :raise
              ->(message) { raise Minitest::Assertion, message }
            when Proc
              behavior
            else
              raise ArgumentError, "assertionless_tests_behavior must be one of :ignore, :log, :raise, or a custom proc."
            end
        end
      end

      def after_teardown
        super

        return if skipped? || error?

        if assertions == 0 && (behavior = self.class.assertionless_tests_behavior)
          file, line = method(name).source_location
          message = "Test is missing assertions: `#{name}` #{file}:#{line}"
          behavior.call(message)
        end
      end
    end
  end
end
