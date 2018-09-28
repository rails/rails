# TODO: Move this to Rails::Conductor gem
class Rails::Conductor::BaseController < ActionController::Base
  layout "rails/conductor"
  before_action :ensure_development_env

  private
    def ensure_development_env
      head :forbidden unless Rails.env.development?
    end
end
