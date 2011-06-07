namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile => :environment do
    # Give assets access to asset_path
    Sprockets::Helpers::RailsHelper

    assets = Rails.application.config.assets.precompile
    Rails.application.assets.precompile(*assets)
  end

  desc "Remove compiled assets"
  task :clean => :environment do
    assets = Rails.application.config.assets
    public_asset_path = Rails.public_path + assets.prefix
    file_list = FileList.new("#{public_asset_path}/*.js", "#{public_asset_path}/*.css")
    file_list.each do |file|
      rm file
      rm "#{file}.gz", :force => true
    end
  end
end
