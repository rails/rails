namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile => :environment do
    assets = Rails.application.config.assets.precompile
    Rails.application.assets.precompile(*assets)
  end
end
