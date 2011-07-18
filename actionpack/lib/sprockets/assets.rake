namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    if ENV["RAILS_GROUPS"].to_s.empty?
      ENV["RAILS_GROUPS"] = "assets"
      Kernel.exec $0, *ARGV
    else
      Rake::Task["environment"].invoke
      Sprockets::Helpers::RailsHelper

      assets = Rails.application.config.assets.precompile
      Rails.application.assets.precompile(*assets)
    end
  end

  desc "Remove compiled assets"
  task :clean => :environment do
    assets = Rails.application.config.assets
    public_asset_path = Rails.public_path + assets.prefix
    rm_rf public_asset_path, :secure => true
  end
end
