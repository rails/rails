require "sprockets"

# TODO: Move this to sprockets-rails
# If so, we can move the require to a Gemfile and remove assets.enabled
class Sprockets::Railtie < Rails::Railtie
  # Configure ActionController to use sprockets.
  initializer "sprockets.set_configs", :after => "action_controller.set_configs" do |app|
    ActiveSupport.on_load(:action_controller) do
      self.use_sprockets = app.config.assets.enabled
    end
  end

  # We need to configure this after initialization to ensure we collect
  # paths from all engines. This hook is invoked exactly before routes
  # are compiled.
  config.after_initialize do |app|
    assets = app.config.assets
    next unless assets.enabled

    app.assets = asset_environment(app)
    app.routes.append do
      mount app.assets => assets.prefix
    end

    if config.action_controller.perform_caching
      app.assets = app.assets.index
    end
  end

  protected

  def asset_environment(app)
    assets = app.config.assets
    env = Sprockets::Environment.new(app.root.to_s)
    env.static_root = File.join(app.root.join("public"), assets.prefix)
    env.paths.concat assets.paths
    env.logger = Rails.logger
    env
  end
end