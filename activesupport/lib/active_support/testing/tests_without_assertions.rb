# frozen_string_literal: true

module ActiveSupport
  module Testing
    # Warns when a test case does not perform any assertions.
    #
    # This is helpful in detecting broken tests that do not perform intended assertions.
    module TestsWithoutAssertions # :nodoc:
      def after_teardown
        super

        if assertions.zero? && !skipped? && !error?
          file, line = method(name).source_location
          warn "Test is missing assertions: `#{name}` #{File.expand_path(file)}:#{line}"
        end
      end
    end
  end
end
