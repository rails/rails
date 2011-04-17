require "sprockets"

class Sprockets::Railtie < Rails::Railtie
  initializer "sprockets.set_configs", :after => "action_controller.set_configs" do |app|
    ActiveSupport.on_load(:action_controller) do
      self.use_sprockets = app.config.assets.enabled
    end
  end
end