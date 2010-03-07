namespace :doc do
  desc "Generate documentation for the application. Set custom template with TEMPLATE=/path/to/rdoc/template.rb or title with TITLE=\"Custom Title\""
  Rake::RDocTask.new("app") { |rdoc|
    rdoc.rdoc_dir = 'doc/app'
    rdoc.template = ENV['template'] if ENV['template']
    rdoc.title    = ENV['title'] || "Rails Application Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.options << '--charset' << 'utf-8'
    rdoc.rdoc_files.include('doc/README_FOR_APP')
    rdoc.rdoc_files.include('app/**/*.rb')
    rdoc.rdoc_files.include('lib/**/*.rb')
  }

  desc 'Generate documentation for the Rails framework. Specify path with RAILS_PATH="/path/to/rails"'
  path = ENV['RAILS_PATH']
  unless path && File.directory?(path)
    task :rails do
      if path
        $stderr.puts "Skipping doc:rails, missing Rails directory at #{path}"
      else
        $stderr.puts "Skipping doc:rails, RAILS_PATH environment variable is not set"
      end
    end
  else
    Rake::RDocTask.new("rails") { |rdoc|
      version = "-#{Rails::VERSION::STRING}" unless ENV['RAILS_PATH']
      rdoc.rdoc_dir = 'doc/api'
      rdoc.template = "#{ENV['template']}.rb" if ENV['template']
      rdoc.title    = "Rails Framework Documentation"
      rdoc.options << '--line-numbers' << '--inline-source'
      rdoc.rdoc_files.include('README')

      %w(README CHANGELOG lib/action_mailer/base.rb).each do |file|
        rdoc.rdoc_files.include("#{path}/actionmailer#{version}/#{file}")
      end

      %w(README CHANGELOG lib/action_controller/**/*.rb lib/action_view/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{path}/actionpack#{version}/#{file}")
      end

      %w(README CHANGELOG lib/active_model/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{path}/activemodel#{version}/#{file}")
      end

      %w(README CHANGELOG lib/active_record/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{path}/activerecord#{version}/#{file}")
      end

      %w(README CHANGELOG lib/active_resource.rb lib/active_resource/*).each do |file|
        rdoc.rdoc_files.include("#{path}/activeresource#{version}/#{file}")
      end

      %w(README CHANGELOG lib/active_support/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{path}/activesupport#{version}/#{file}")
      end

      %w(README CHANGELOG MIT-LICENSE lib/{*.rb,commands/*.rb,generators/*.rb}).each do |file|
        rdoc.rdoc_files.include("#{path}/railties#{version}/#{file}")
      end
    }
  end

  plugins = FileList['vendor/plugins/**'].collect { |plugin| File.basename(plugin) }

  desc "Generate documentation for all installed plugins"
  task :plugins => plugins.collect { |plugin| "doc:plugins:#{plugin}" }

  desc "Remove plugin documentation"
  task :clobber_plugins do 
    rm_rf 'doc/plugins' rescue nil
  end

  desc "Generate Rails guides"
  task :guides do
    require File.join(RAILTIES_PATH, "guides/rails_guides")
    RailsGuides::Generator.new(Rails.root.join("doc/guides")).generate
  end

  namespace :plugins do
    # Define doc tasks for each plugin
    plugins.each do |plugin|
      desc "Generate documentation for the #{plugin} plugin"
      task(plugin => :environment) do
        plugin_base   = "vendor/plugins/#{plugin}"
        options       = []
        files         = Rake::FileList.new
        options << "-o doc/plugins/#{plugin}"
        options << "--title '#{plugin.titlecase} Plugin Documentation'"
        options << '--line-numbers' << '--inline-source'
        options << '--charset' << 'utf-8'
        options << '-T html'

        files.include("#{plugin_base}/lib/**/*.rb")
        if File.exist?("#{plugin_base}/README")
          files.include("#{plugin_base}/README")    
          options << "--main '#{plugin_base}/README'"
        end
        files.include("#{plugin_base}/CHANGELOG") if File.exist?("#{plugin_base}/CHANGELOG")

        options << files.to_s

        sh %(rdoc #{options * ' '})
      end
    end
  end
end
