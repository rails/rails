# frozen_string_literal: true

module ActionController #:nodoc:
  module FeaturePolicy
    extend ActiveSupport::Concern

    module ClassMethods
      def feature_policy(**options, &block)
        before_action(options) do
          if block_given?
            policy = request.feature_policy.clone
            yield policy
            request.feature_policy = policy
          end
        end
      end
    end
  end
end
