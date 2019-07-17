# frozen_string_literal: true

module ActionController #:nodoc:
  # HTTP Feature Policy is a web standard for defining a mechanism to
  # allow and deny the use of browser features in its own context, and
  # in content within any <iframe> elements in the document.
  #
  # Full details of HTTP Feature Policy specification and guidelines can
  # be found at MDN:
  #
  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Feature-Policy
  #
  # Examples of usage:
  #
  #   # Global policy
  #   Rails.application.config.feature_policy do |f|
  #     f.camera      :none
  #     f.gyroscope   :none
  #     f.microphone  :none
  #     f.usb         :none
  #     f.fullscreen  :self
  #     f.payment     :self, "https://secure.example.com"
  #   end
  #
  #   # Controller level policy
  #   class PagesController < ApplicationController
  #     feature_policy do |p|
  #       p.geolocation "https://example.com"
  #     end
  #   end
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
