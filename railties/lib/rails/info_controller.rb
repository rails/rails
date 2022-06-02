# frozen_string_literal: true

require "rails/application_controller"
require "action_dispatch/routing/inspector"

class Rails::InfoController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugView::RESCUES_TEMPLATE_PATH
  layout -> { request.xhr? ? false : "application" }

  before_action :require_local!

  def index
    redirect_to action: :routes
  end

  def properties
    @info = Rails::Info.to_html
    @page_title = "Properties"
  end

  def routes
    if path = params[:path]
      path = URI::DEFAULT_PARSER.escape path
      normalized_path = with_leading_slash path
      render json: {
        exact: match_route { |it| it.match normalized_path },
        fuzzy: match_route { |it| it.spec.to_s.match path }
      }
    else
      @routes_inspector = ActionDispatch::Routing::RoutesInspector.new(_routes.routes)
      @page_title = "Routes"
    end
  end

  private
    def match_route
      _routes.routes.filter_map { |route| route.path.spec.to_s if yield route.path }
    end

    def with_leading_slash(path)
      ("/" + path).squeeze("/")
    end
end
