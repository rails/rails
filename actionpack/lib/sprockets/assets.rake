require "fileutils"

namespace :assets do
  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    Rake::Task["assets:internal:invoke"].invoke("compile:all")
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

    def app
      @app ||= Rails.application
    end

    def assets
      @assets_config ||= app.config.assets
    end

    namespace :compile do
      def mode=(mode)
        unless [:primary, :digestless].include?(mode)
          raise "Unknown asset compilation mode: #{mode}. Please use one of: primary, digestless"
        end
        @mode = ActiveSupport::StringInquirer.new(mode.to_s)
      end

      def mode
        @mode ||= ActiveSupport::StringInquirer.new('primary')
      end

      def compile
        unless assets.enabled
          raise "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
        end
        
        # Ensure that action view is loaded and the appropriate
        # sprockets hooks get executed
        _ = ActionView::Base
        
        assets.digest = false if mode.digestless?
        assets.compile = true
        assets.digests = {}

        target = File.join(Rails.public_path, assets.prefix)
        compiler = Sprockets::StaticCompiler.new(app.assets, 
                                                 target,
                                                 assets.precompile,
                                                 :manifest_path => assets.manifest,
                                                 :digest => assets.digest,
                                                 :manifest => mode.primary?)
        compiler.compile
      end

      def invoke_digestless?
        assets.digest && !assets.skip_digestless
      end

      task :all => ["assets:internal:environment", "tmp:cache:clear"] do
        Rake::Task["assets:internal:compile:primary"].invoke
        # We need to reinvoke in order to run the secondary digestless
        # asset compilation run - a fresh Sprockets environment is
        # required in order to compile digestless assets as the
        # environment has already cached the assets on the primary
        # run.
        reinvoke_for("compile:digestless") if invoke_digestless?
      end

      task :primary => ["assets:internal:environment", "tmp:cache:clear"] do 
        compile
      end

      task :digestless => ["assets:internal:environment", "tmp:cache:clear"] do 
        self.mode = :digestless
        compile
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
