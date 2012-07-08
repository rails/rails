require 'action_dispatch/routing/inspector'

class Rails::InfoController < ActionController::Base
  self.view_paths = File.join(File.dirname(__FILE__), 'templates')
  layout 'application'

  before_filter :require_local!

  def index
    redirect_to '/rails/info/routes'
  end

  def properties
    @info = Rails::Info.to_html
  end

  def routes
    inspector = ActionDispatch::Routing::RoutesInspector.new
    @info     = inspector.format(_routes.routes).join("\n")
  end

  protected

  def require_local!
    unless local_request?
      render :text => '<p>For security purposes, this information is only available to local requests.</p>', :status => :forbidden
    end
  end

  def local_request?
    Rails.application.config.consider_all_requests_local || request.local?
  end
end
