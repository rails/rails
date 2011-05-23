require 'uri'
require 'action_view/helpers/asset_paths'

module ActionView
  module Helpers
    module SprocketsHelper
      def debug_assets?
        params[:debug_assets] == '1' ||
          params[:debug_assets] == 'true'
      end

    end
  end
end
