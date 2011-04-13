namespace :assets do
  task :compile => :environment do
    assets = Rails.application.config.assets.precompile
    Rails.application.assets.precompile(*assets)
  end
end
