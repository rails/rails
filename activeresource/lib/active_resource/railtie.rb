require "active_resource"
require "rails"

module ActiveResource
  class Railtie < Rails::Railtie
    plugin_name :active_resource

    require "active_resource/railties/subscriber"
    subscriber ActiveResource::Railties::Subscriber.new
  end
end