# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    module AmazonSes
      def self.config
        @config ||= Rails.application.config_for(:mailbox).fetch(:amazon_ses)
      end

      class BaseController < ActionMailbox::BaseController
        before_action :set_notification, :ensure_valid_topic, :ensure_verified

        def ingress_name
          :amazon_ses
        end

        private
          def set_notification
            require "action_mailbox/amazon_ses/sns_notification"

            @notification = ::ActionMailbox::AmazonSes::SnsNotification.new(request.raw_post)
          end

          def ensure_valid_topic
            return if @notification.topic.in? Array(AmazonSes.config.fetch(:subscribed_topics))

            Rails.logger.warn "Ignoring unknown topic: #{@notification.topic}"
            head :unauthorized
          end

          def ensure_verified
            head :unauthorized unless @notification.verified?
          end
      end
    end
  end
end
