# frozen_string_literal: true

module Rails
  class Conductor::BaseController < ActionController::Base
    layout "rails/conductor"
    before_action :ensure_development_env

    private
      def ensure_development_env
        head :forbidden unless Rails.env.development?
      end
  end
end
