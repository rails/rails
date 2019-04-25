# frozen_string_literal: true

module ActionMailbox
  # The base class for all Action Mailbox ingress controllers.
  class BaseController < ActionController::Base
    skip_forgery_protection if default_protect_from_forgery

    before_action :ensure_configured

    private
      def ensure_configured
        unless ActionMailbox.ingress == ingress_name
          head :not_found
        end
      end

      def ingress_name
        self.class.name.remove(/\AActionMailbox::Ingresses::/, /::InboundEmailsController\z/).underscore.to_sym
      end


      def authenticate_by_password
        if password.present?
          http_basic_authenticate_or_request_with name: "actionmailbox", password: password, realm: "Action Mailbox"
        else
          raise ArgumentError, "Missing required ingress credentials"
        end
      end

      def password
        Rails.application.credentials.dig(:action_mailbox, :ingress_password) || ENV["RAILS_INBOUND_EMAIL_PASSWORD"]
      end
  end
end
