require "fileutils"

namespace :assets do
  def ruby_rake_task(task, fork = true)
    env    = ENV['RAILS_ENV'] || 'production'
    groups = ENV['RAILS_GROUPS'] || 'assets'
    args   = [$0, task,"RAILS_ENV=#{env}","RAILS_GROUPS=#{groups}"]
    args << "--trace" if Rake.application.options.trace
    if $0 =~ /rake\.bat\Z/i
      Kernel.exec $0, *args
    else  
      fork ? ruby(*args) : Kernel.exec(FileUtils::RUBY, *args)
    end    
  end

  # We are currently running with no explicit bundler group
  # and/or no explicit environment - we have to reinvoke rake to
  # execute this task.
  def invoke_or_reboot_rake_task(task)
    if ENV['RAILS_GROUPS'].to_s.empty? || ENV['RAILS_ENV'].to_s.empty?
      ruby_rake_task task
    else
      Rake::Task[task].invoke
    end
  end

  desc "Compile all the assets named in config.assets.precompile"
  task :precompile do
    invoke_or_reboot_rake_task "assets:precompile:all"
  end

  namespace :precompile do
    def symlink_public_assets(digest=nil)
      root = "#{Rails.root}/app/assets/public/"
      Dir["#{root}*"].each do |p|
        origin = p
        path = p.gsub(root, '')
        source = File.expand_path(File.join(Rails.public_path, ActionController::Base.helpers.asset_path(path)))
        destination = "#{Rails.public_path}/#{path}"
        File.unlink(destination) if File.exists?(destination) && File.symlink?(destination)
        File.symlink(source, destination)
      end
    end

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

      env      = Rails.application.assets
      target   = File.join(Rails.public_path, config.assets.prefix)
      compiler = Sprockets::StaticCompiler.new(env,
                                               target,
                                               config.assets.precompile,
                                               :manifest_path => config.assets.manifest,
                                               :digest => config.assets.digest,
                                               :manifest => digest.nil?)
      compiler.compile
      symlink_public_assets(config.assets.digest)
    end

    task :all do
      Rake::Task["assets:precompile:primary"].invoke
      # We need to reinvoke in order to run the secondary digestless
      # asset compilation run - a fresh Sprockets environment is
      # required in order to compile digestless assets as the
      # environment has already cached the assets on the primary
      # run.
      ruby_rake_task("assets:precompile:nondigest", false) if Rails.application.config.assets.digest
    end

    task :primary => ["assets:cache:clean"] do
      internal_precompile
    end

    task :nondigest => ["assets:cache:clean"] do
      if Rails.application.config.assets.nondigest_enabled || Rails.application.config.assets.nondigest_enabled.nil?
        internal_precompile(false)
      else
        warn "Skipping assets:precompile:nondigest set config.assets.nondigest_enabled to true if required"
      end
    end
  end

  desc "Remove compiled assets"
  task :clean do
    invoke_or_reboot_rake_task "assets:clean:all"
  end

  namespace :clean do
    task :all => ["assets:cache:clean"] do
      config = Rails.application.config
      public_asset_path = File.join(Rails.public_path, config.assets.prefix)
      rm_rf public_asset_path, :secure => true
    end
  end

  namespace :cache do
    task :clean => ["assets:environment"] do
      Rails.application.assets.cache.clear
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
