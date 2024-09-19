# frozen_string_literal: true

require "rails/application_controller"
require "action_dispatch/routing/inspector"

class Rails::ToolsController < Rails::ApplicationController # :nodoc:
  before_action :require_local!

  def index
    @grouped_options = {
      "Info": {
        "Routes": "/rails/info/routes",
        "Notes": "/rails/info/notes",
        "Properties": "/rails/info/properties",
      },
      "Mailers": {
        "Preview": "/rails/mailers"
      }
    }
  end
end
