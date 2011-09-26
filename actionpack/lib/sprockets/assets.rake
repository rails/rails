namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    # We need to do this dance because RAILS_GROUPS is used
    # too early in the boot process and changing here is already too late.
    if ENV["RAILS_GROUPS"].to_s.empty? || ENV["RAILS_ENV"].to_s.empty?
      ENV["RAILS_GROUPS"] ||= "assets"
      ENV["RAILS_ENV"]    ||= "production"
      ruby $0, *ARGV
    else
      require "fileutils"
      Rake::Task["tmp:cache:clear"].invoke
      Rake::Task["assets:environment"].invoke

      unless Rails.application.config.assets.enabled
        raise "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
      end

      # Ensure that action view is loaded and the appropriate sprockets hooks get executed
      ActionView::Base

      config = Rails.application.config
      config.assets.compile = true
      config.assets.digest = false if ENV["RAILS_ASSETS_NONDIGEST"]

      env    = Rails.application.assets

      # Always compile files and avoid use of existing precompiled assets
      config.assets.compile = true
      config.assets.digests = {}

      target = File.join(Rails.public_path, config.assets.prefix)
      static_compiler = Sprockets::StaticCompiler.new(env, target, :digest => config.assets.digest)

      manifest = static_compiler.precompile(config.assets.precompile)
      manifest_path = config.assets.manifest || target
      FileUtils.mkdir_p(manifest_path)

      unless ENV["RAILS_ASSETS_NONDIGEST"]
        File.open("#{manifest_path}/manifest.yml", 'wb') do |f|
          YAML.dump(manifest, f)
        end
        ENV["RAILS_ASSETS_NONDIGEST"] = "true"
        ruby $0, *ARGV
      end
    end
  end

  desc "Remove compiled assets"
  task :clean => ['assets:environment', 'tmp:cache:clear'] do
    config = Rails.application.config
    public_asset_path = File.join(Rails.public_path, config.assets.prefix)
    rm_rf public_asset_path, :secure => true
  end

  task :environment do
    Rails.application.initialize!(:assets)
    Sprockets::Bootstrap.new(Rails.application).run
  end
end
