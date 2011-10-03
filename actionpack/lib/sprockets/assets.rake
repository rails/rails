require "fileutils"

namespace :assets do
  def invoke_precompile
    args = [$0, "assets:internal_precompile"]
    args << "--trace" if Rake.application.options.trace
    ruby *args
  end

  desc "Compile all the assets named in config.assets.precompile"
  task :precompile => "assets:clean" do
    ENV["RAILS_GROUPS"] ||= "assets"
    ENV["RAILS_ENV"]    ||= "production"
    invoke_precompile
  end

  task :internal_precompile => "assets:environment" do
    unless Rails.application.config.assets.enabled
      raise "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
    end

    # Ensure that action view is loaded and the appropriate sprockets hooks get executed
    _ = ActionView::Base

    config = Rails.application.config
    config.assets.compile = true
    config.assets.digest  = false if ENV["RAILS_ASSETS_NONDIGEST"]
    config.assets.digests = {}

    env    = Rails.application.assets
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
      invoke_precompile
    end
  end

  desc "Remove compiled assets"
  task :clean => "tmp:cache:clear" do
    config = Rails.application.config
    public_asset_path = File.join(Rails.public_path, config.assets.prefix)
    rm_rf public_asset_path, :secure => true
  end

  task :environment do
    if Rails.application.config.assets.initialize_on_precompile
      Rake::Task["environment"].invoke
    else
      Rails.application.initialize!(:assets)
      Sprockets::Bootstrap.new(Rails.application).run
    end
  end
end
