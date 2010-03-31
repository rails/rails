require "action_view"
require "rails"

module ActionView
  class Railtie < Rails::Railtie
    config.action_view = ActiveSupport::OrderedOptions.new

    require "action_view/railties/log_subscriber"
    log_subscriber :action_view, ActionView::Railties::LogSubscriber.new

    initializer "action_view.cache_asset_timestamps" do |app|
      unless app.config.cache_classes
        ActiveSupport.on_load(:action_view) do
          ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
        end
      end
    end

    initializer "action_view.set_configs" do |app|
      ActiveSupport.on_load(:action_view) do
        app.config.action_view.each do |k,v|
          send "#{k}=", v
        end
      end
    end
  end
end