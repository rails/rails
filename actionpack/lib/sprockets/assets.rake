namespace :assets do
  # Ensures the RAILS_GROUPS environment variable is set
  task :ensure_env do
    ENV["RAILS_GROUPS"] ||= "assets"
  end

  desc "Compile all the assets named in config.assets.precompile"
  task :precompile => :ensure_env do
    Rake::Task["environment"].invoke
    Sprockets::Helpers::RailsHelper

    assets = Rails.application.config.assets.precompile
    # Always perform caching so that asset_path appends the timestamps to file references.
    Rails.application.config.action_controller.perform_caching = true
    Rails.application.assets.precompile(*assets)
  end

  desc "Remove compiled assets"
  task :clean => :environment do
    assets = Rails.application.config.assets
    public_asset_path = Rails.public_path + assets.prefix
    rm_rf public_asset_path, :secure => true
  end
end
