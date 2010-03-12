require "action_view"
require "rails"

module ActionView
  class Railtie < Rails::Railtie
    railtie_name :action_view

    require "action_view/railties/log_subscriber"
    log_subscriber ActionView::Railties::LogSubscriber.new

    initializer "action_view.cache_asset_timestamps" do |app|
      unless app.config.cache_classes
        ActionView.base_hook do
          ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
        end
      end
    end
  end
end