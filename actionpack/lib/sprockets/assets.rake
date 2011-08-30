namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    # We need to do this dance because RAILS_GROUPS is used
    # too early in the boot process and changing here is already too late.
    if ENV["RAILS_GROUPS"].to_s.empty? || ENV["RAILS_ENV"].to_s.empty?
      ENV["RAILS_GROUPS"] ||= "assets"
      ENV["RAILS_ENV"]    ||= "production"
      Kernel.exec $0, *ARGV
    else
      Rake::Task["environment"].invoke

      # Ensure that action view is loaded and the appropriate sprockets hooks get executed
      ActionView::Base

      # Always perform caching so that asset_path appends the timestamps to file references.
      Rails.application.config.action_controller.perform_caching = true

      config = Rails.application.config
      env    = Rails.application.assets
      target = Pathname.new(File.join(Rails.public_path, config.assets.prefix))
      manifest = {}
      manifest_path = config.assets.manifest || target

      if env.respond_to?(:each_logical_path)
        config.assets.precompile.each do |path|
          env.each_logical_path do |logical_path|
            if path.is_a?(Regexp)
              next unless path.match(logical_path)
            else
              next unless File.fnmatch(path.to_s, logical_path)
            end

            if asset = env.find_asset(logical_path)
              manifest[logical_path] = asset.digest_path
              filename = target.join(asset.digest_path)
              mkdir_p filename.dirname
              asset.write_to(filename)
              asset.write_to("#{filename}.gz") if filename.to_s =~ /\.(css|js)$/
            end
          end
        end
      else
        # TODO: Remove this once we're depending on sprockets beta 15
        assets = config.assets.precompile.dup
        assets << {:to => target}
        env.precompile(*assets)
      end

      File.open("#{manifest_path}/manifest.yml", 'w') do |f|
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
