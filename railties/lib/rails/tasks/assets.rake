namespace :assets do
  task :compile => :environment do
    assets = ENV['assets'].split(',')
    Rails.application.assets.precompile(*assets)
  end
end
