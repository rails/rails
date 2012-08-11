require 'action_controller/metal/exceptions'

module ActionController
  module AssetPaths
    extend ActiveSupport::Concern

    included do
      include AbstractController::AssetPaths
    end

    def invalid_asset_host!(help_message)
      raise ActionController::RoutingError, "This asset host cannot be computed without a request in scope. #{help_message}"
    end
  end
end
