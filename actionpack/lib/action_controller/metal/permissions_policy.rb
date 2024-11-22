# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module PermissionsPolicy
    extend ActiveSupport::Concern

    module ClassMethods
      # Overrides parts of the globally configured `Feature-Policy` header:
      #
      #     class PagesController < ApplicationController
      #       permissions_policy do |policy|
      #         policy.geolocation "https://example.com"
      #       end
      #     end
      #
      # Options can be passed similar to `before_action`. For example, pass `only:
      # :index` to override the header on the index action only:
      #
      #     class PagesController < ApplicationController
      #       permissions_policy(only: :index) do |policy|
      #         policy.camera :self
      #       end
      #     end
      #
      # Requires a global policy defined in an initializer, which can be
      # empty:
      #
      #     Rails.application.config.permissions_policy do |policy|
      #       # policy.gyroscope :none
      #     end
      def permissions_policy(**options, &block)
        before_action(options) do
          unless request.respond_to?(:permissions_policy)
            raise "Cannot override permissions_policy if no global permissions_policy configured."
          end
          if block_given?
            policy = request.permissions_policy.clone
            instance_exec(policy, &block)
            request.permissions_policy = policy
          end
        end
      end
    end
  end
end
