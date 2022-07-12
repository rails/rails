# frozen_string_literal: true

module ActiveRecord
  module DynamicIncludes
    extend ActiveSupport::Concern
    class LoadTreeNotEnabledError < StandardError; end

    included do
      def self.dynamic_includes_enabled=(value)
        raise LoadTreeNotEnabledError, "load_tree must be enabled in order to use dynamic includes" unless ActiveRecord.load_tree_enabled
        ActiveSupport::IsolatedExecutionState[:dynamic_includes_enabled] = value
      end

      def self.dynamic_includes_enabled?
        ActiveSupport::IsolatedExecutionState[:dynamic_includes_enabled] ||= false
      end

      def self.with_dynamic_includes(enabled: true)
        prior_value = self.dynamic_includes_enabled?
        self.dynamic_includes_enabled = enabled
        yield
      ensure
        self.dynamic_includes_enabled = prior_value
      end
    end
  end
end
