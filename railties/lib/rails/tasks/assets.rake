namespace :assets do
  task :compile => :environment do
    assets = Rails.application.config.precompile_assets
    Rails.application.assets.precompile(*assets)
  end
end
