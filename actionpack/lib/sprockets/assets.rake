require "fileutils"

namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    Rake::Task["assets:internal:invoke"].invoke("compile[primary]")
  end

  desc "Remove compiled assets"
  task :clean do
    Rake::Task["assets:internal:invoke"].invoke("clean")
  end

  namespace :internal do
    def reinvoke_for(task)
      env = ENV['RAILS_ENV'] || 'production'
      groups = ENV['RAILS_GROUPS'] || 'assets'
      args = [$0, "assets:internal:#{task}","RAILS_ENV=#{env}","RAILS_GROUPS=#{groups}"]
      args << "--trace" if Rake.application.options.trace
      ruby *args
    end

    def app
      @app ||= Rails.application
    end

    def assets
      @assets_config ||= app.config.assets
    end

    def compiler(mode)
      Sprockets::StaticCompiler.compiler_for(assets, app.assets, mode)
    end

    def invoke_digestless?
      assets.digest && !assets.skip_digestless
    end

    task :invoke, [:task] do |this, args|
      task = args[:task]
      if ENV['RAILS_GROUPS'].to_s.empty? || ENV['RAILS_ENV'].to_s.empty?
        # We are currently running with no explicit bundler group
        # and/or no explicit environment - we have to reinvoke rake to
        # execute this task.
        reinvoke_for(task)
      else
        Rake::Task["assets:internal:#{task}"].invoke
      end
      this.reenable
    end

    task :compile, [:mode] => ["assets:internal:environment", "tmp:cache:clear"] do |t, args|
      mode = args[:mode] || 'primary'
      compiler(mode).compile
      if mode == 'primary' && invoke_digestless?
        # We need to reinvoke in order to run the secondary asset
        # compilation run - a fresh Sprockets environment is
        # required in order to compile digestless assets.
        reinvoke_for("compile[digestless]") if invoke_digestless?
      end
    end

    task :clean => ["assets:internal:environment", "tmp:cache:clear"] do
      public_asset_path = File.join(Rails.public_path, assets.prefix)
      rm_rf(public_asset_path, :secure => true)
    end
    
    task :environment do
      if assets.initialize_on_precompile
        Rake::Task["environment"].invoke
      else
        app.initialize!(:assets)
        Sprockets::Bootstrap.new(app).run
      end
    end
  end
end
