# frozen_string_literal: true

require "active_support/deprecation"
require "active_support/core_ext/regexp"

module ActiveSupport
  module Testing
    module Deprecation #:nodoc:
      def assert_deprecated(match = nil, deprecator = nil, &block)
        result, warnings = collect_deprecations(deprecator, &block)
        assert !warnings.empty?, "Expected a deprecation warning within the block but received none"
        if match
          match = Regexp.new(Regexp.escape(match)) unless match.is_a?(Regexp)
          assert warnings.any? { |w| match.match?(w) }, "No deprecation warning matched #{match}: #{warnings.join(', ')}"
        end
        result
      end

      def assert_not_deprecated(deprecator = nil, &block)
        result, deprecations = collect_deprecations(deprecator, &block)
        assert deprecations.empty?, "Expected no deprecation warning within the block but received #{deprecations.size}: \n  #{deprecations * "\n  "}"
        result
      end

      def collect_deprecations(deprecator = nil)
        deprecator ||= ActiveSupport::Deprecation
        old_behavior = deprecator.behavior
        deprecations = []
        deprecator.behavior = Proc.new do |message, callstack|
          deprecations << message
        end
        result = yield
        [result, deprecations]
      ensure
        deprecator.behavior = old_behavior
      end
    end
  end
end
