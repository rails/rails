namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    # We need to do this dance because RAILS_GROUPS is used
    # too early in the boot process and changing here is already too late.
    if ENV["RAILS_GROUPS"].to_s.empty? || ENV["RAILS_ENV"].to_s.empty?
      ENV["RAILS_GROUPS"] ||= "assets"
      ENV["RAILS_ENV"]    ||= "production"
      Kernel.exec $0, *ARGV
    else
      Rake::Task["environment"].invoke

      # Ensure that action view is loaded and the appropriate sprockets hooks get executed
      ActionView::Base

      # Always perform caching so that asset_path appends the timestamps to file references.
      Rails.application.config.action_controller.perform_caching = true

      config = Rails.application.config
      assets = config.assets.precompile.dup
      assets << {:to => File.join(Rails.public_path, config.assets.prefix)}
      Rails.application.assets.precompile(*assets)
    end
  end

  desc "Remove compiled assets"
  task :clean => [:environment, 'tmp:cache:clear'] do
    config = Rails.application.config
    public_asset_path = File.join(Rails.public_path, config.assets.prefix)
    rm_rf public_asset_path, :secure => true
  end
end
