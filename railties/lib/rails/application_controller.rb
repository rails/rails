class Rails::ApplicationController < ActionController::Base # :nodoc:
  self.view_paths = File.expand_path('../templates', __FILE__)
  layout 'application'

  protected

  def require_local!
    unless local_request?
      render html: '<p>For security purposes, this information is only available to local requests.</p>'.html_safe, status: :forbidden
    end
  end

  def local_request?
    Rails.application.config.consider_all_requests_local || request.local?
  end
end
