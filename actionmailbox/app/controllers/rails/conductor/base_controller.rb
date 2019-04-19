# frozen_string_literal: true

module Rails
  # TODO: Move this to Rails::Conductor gem
  class Conductor::BaseController < ActionController::Base
    layout "rails/conductor"
    before_action :ensure_development_env

    rescue_from ActiveRecord::StatementInvalid, with: :raise_table_missing_error

    private
      def ensure_development_env
        head :forbidden unless Rails.env.development?
      end

      def raise_table_missing_error(exception)
        if exception.message.match?(%r{#{ActionMailbox::InboundEmail.table_name}})
          raise ActionMailbox::InboundEmailTableMissingError
        else
          raise exception
        end
      end
  end
end
