# frozen_string_literal: true

module ActiveSupport
  module Testing
    # Warns when a test case does not perform any assertions.
    #
    # This is helpful in detecting broken tests that do not perform intended assertions.
    module TestsWithoutAssertions # :nodoc:
      def after_teardown
        super

        return if skipped? || error?

        if assertions == 0
          file, line = method(name).source_location
          message = "Test is missing assertions: `#{name}` #{file}:#{line}"
          warn message
        end
      end
    end
  end
end
