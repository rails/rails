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
      Rails.application.initialize!(:assets)
      Sprockets::Bootstrap.new(Rails.application).run

      unless Rails.application.config.assets.enabled
        raise "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
      end

      # Ensure that action view is loaded and the appropriate sprockets hooks get executed
      ActionView::Base

      # Always compile files
      Rails.application.config.assets.compile = true

      config = Rails.application.config
      env    = Rails.application.assets

      target = File.join(Rails.public_path, config.assets.prefix)
      static_compiler = Sprockets::StaticCompiler.new(env, target, :digest => config.assets.digest)

      manifest = static_compiler.precompile(config.assets.precompile)
      manifest_path = config.assets.manifest || target
      FileUtils.mkdir_p(manifest_path)

      File.open("#{manifest_path}/manifest.yml", 'wb') do |f|
        YAML.dump(manifest, f)
      end
    end
  end

  desc "Remove compiled assets"
  task :clean => [:environment, 'tmp:cache:clear'] do
    config = Rails.application.config
    public_asset_path = File.join(Rails.public_path, config.assets.prefix)
    rm_rf public_asset_path, :secure => true
  end
end
