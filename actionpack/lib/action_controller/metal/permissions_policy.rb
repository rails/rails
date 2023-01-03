# frozen_string_literal: true

module ActionController # :nodoc:
  module PermissionsPolicy
    extend ActiveSupport::Concern

    module ClassMethods
      # Overrides parts of the globally configured +Feature-Policy+
      # header:
      #
      #   class PagesController < ApplicationController
      #     permissions_policy do |policy|
      #       policy.geolocation "https://example.com"
      #     end
      #   end
      #
      # Options can be passed similar to +before_action+. For example, pass
      # <tt>only: :index</tt> to override the header on the index action only:
      #
      #   class PagesController < ApplicationController
      #     permissions_policy(only: :index) do |policy|
      #       policy.camera :self
      #     end
      #   end
      #
      def permissions_policy(**options, &block)
        before_action(options) do
          if block_given?
            policy = request.permissions_policy.clone
            yield policy
            request.permissions_policy = policy
          end
        end
      end
    end
  end
end
