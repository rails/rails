class Rails::ApplicationController < ActionController::Base # :nodoc:
  self.view_paths = File.expand_path('../templates', __FILE__)
  layout 'application'

  before_action :set_locale

  protected

  def require_local!
    unless local_request?
      render text: '<p>For security purposes, this information is only available to local requests.</p>', status: :forbidden
    end
  end

  def local_request?
    Rails.application.config.consider_all_requests_local || request.local?
  end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end
end
