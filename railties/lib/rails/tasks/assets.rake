require "fileutils"

namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile => :environment do
    # Give assets access to asset_path
    Sprockets::Helpers::RailsHelper

    assets = Rails.application.config.assets.precompile
    Rails.application.assets.precompile(*assets)
  end

  desc "Remove compiled assets"
  task :cleanup => :environment do
    assets = Rails.application.config.assets
    public_asset_path = Rails.public_path + assets.prefix
    FileUtils.rm_r Dir.glob("#{public_asset_path}/*.js")
    FileUtils.rm_r Dir.glob("#{public_asset_path}/*.css")
  end
end
