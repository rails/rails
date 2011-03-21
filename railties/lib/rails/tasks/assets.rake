namespace :assets do
  task :compile => :environment do
    env = Rails.application.assets

    assets = Rails.root.join("public/assets")
    assets.mkdir unless assets.exist?

    Rails.application.config.compile_assets.each do |path|
      assets.join(path).open('w') do |f|
        f.write env[path].to_s
      end
    end
  end
end
