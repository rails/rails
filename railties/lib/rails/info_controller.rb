require 'action_dispatch/routing/inspector'

class Rails::InfoController < ActionController::Base # :nodoc:
  self.view_paths = File.expand_path('../templates', __FILE__)
  prepend_view_path ActionDispatch::DebugExceptions::RESCUES_TEMPLATE_PATH
  layout -> { request.xhr? ? nil : 'application' }

  before_filter :require_local!

  def index
    redirect_to action: :routes
  end

  def properties
    @info = Rails::Info.to_html
  end

  def routes
    @routes_inspector = ActionDispatch::Routing::RoutesInspector.new(_routes.routes)
  end

  protected

  def require_local!
    unless local_request?
      render text: '<p>For security purposes, this information is only available to local requests.</p>', status: :forbidden
    end
  end

  def local_request?
    Rails.application.config.consider_all_requests_local || request.local?
  end
end
