require "action_view"
require "rails"

module ActionView
  class Railtie < Rails::Railtie
    plugin_name :action_view

    require "action_view/railties/subscriber"
    subscriber ActionView::Railties::Subscriber.new
  end
end