require "fileutils"

namespace :assets do
  def ruby_rake_task(task)
    args = [$0, task]
    args << "--trace" if Rake.application.options.trace
    ruby *args
  end

  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    ENV["RAILS_GROUPS"] ||= "assets"
    ENV["RAILS_ENV"]    ||= "production"
    ruby_rake_task "assets:precompile:all"
  end

  namespace :precompile do
    def internal_precompile(digest=nil)
      unless Rails.application.config.assets.enabled
        warn "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
        exit
      end

      # Ensure that action view is loaded and the appropriate
      # sprockets hooks get executed
      _ = ActionView::Base

      config = Rails.application.config
      config.assets.compile = true
      config.assets.digest  = digest unless digest.nil?

      config.assets.digests = {}

      env    = Rails.application.assets
      target = File.join(Rails.public_path, config.assets.prefix)
      compiler = Sprockets::StaticCompiler.new(env, 
                                               target,
                                               config.assets.precompile,
                                               :manifest_path => config.assets.manifest,
                                               :digest => config.assets.digest,
                                               :manifest => digest.nil?)
      compiler.compile
    end

    task :all do
      Rake::Task["assets:precompile:digest"].invoke
      ruby_rake_task "assets:precompile:nondigest"
    end

    task :digest => ["assets:environment", "tmp:cache:clear"] do
      internal_precompile
    end

    task :nondigest => ["assets:environment", "tmp:cache:clear"] do
      internal_precompile(false)
    end
  end

  desc "Remove compiled assets"
  task :clean do
    ENV["RAILS_GROUPS"] ||= "assets"
    ENV["RAILS_ENV"]    ||= "production"
    ruby_rake_task "assets:clean:all"
  end

  namespace :clean do
    task :all => ["assets:environment", "tmp:cache:clear"] do
      config = Rails.application.config
      public_asset_path = File.join(Rails.public_path, config.assets.prefix)
      rm_rf public_asset_path, :secure => true
    end
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
