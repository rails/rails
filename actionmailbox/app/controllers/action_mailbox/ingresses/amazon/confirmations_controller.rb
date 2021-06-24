# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    module Amazon
      class ConfirmationsController < BaseController
        def create
          if @notification.subscription_confirmed?
            head :ok
          else
            Rails.logger.error "SNS subscription confirmation request rejected."
            head :unprocessable_entity
          end
        end
      end
    end
  end
end
