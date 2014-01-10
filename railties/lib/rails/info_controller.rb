require 'rails/application_controller'
require 'action_dispatch/routing/inspector'

class Rails::InfoController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugExceptions::RESCUES_TEMPLATE_PATH
  layout -> { request.xhr? ? false : 'application' }

  before_filter :require_local!

  def index
    redirect_to action: :routes
  end

  def properties
    @info = Rails::Info.to_html
    @page_title = 'Properties'
  end

  def routes
    @routes_inspector = ActionDispatch::Routing::RoutesInspector.new(_routes.routes)
    @page_title = 'Routes'
  end
end
