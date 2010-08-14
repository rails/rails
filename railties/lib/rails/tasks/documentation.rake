require 'rake/rdoctask'

# Monkey-patch to remove redoc'ing and clobber descriptions to cut down on rake -T noise
class RDocTaskWithoutDescriptions < Rake::RDocTask
  def define
    task rdoc_task_name

    task rerdoc_task_name => [clobber_task_name, rdoc_task_name]

    task clobber_task_name do
      rm_r rdoc_dir rescue nil
    end

    task :clobber => [clobber_task_name]

    directory @rdoc_dir
    task rdoc_task_name => [rdoc_target]
    file rdoc_target => @rdoc_files + [Rake.application.rakefile] do
      rm_r @rdoc_dir rescue nil
      @before_running_rdoc.call if @before_running_rdoc
      args = option_list + @rdoc_files
      if @external
        argstring = args.join(' ')
        sh %{ruby -Ivendor vendor/rd #{argstring}}
      else
        require 'rdoc/rdoc'
        RDoc::RDoc.new.document(args)
      end
    end
    self
  end
end

namespace :doc do
  def gem_path(gem_name)
    path = $LOAD_PATH.grep(/#{gem_name}[\w.-]*\/lib$/).first
    yield File.dirname(path) if path
  end

  RDocTaskWithoutDescriptions.new("app") { |rdoc|
    rdoc.rdoc_dir = 'doc/app'
    rdoc.template = ENV['template'] if ENV['template']
    rdoc.title    = ENV['title'] || "Rails Application Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.options << '--charset' << 'utf-8'
    rdoc.rdoc_files.include('doc/README_FOR_APP')
    rdoc.rdoc_files.include('app/**/*.rb')
    rdoc.rdoc_files.include('lib/**/*.rb')
  }
  Rake::Task['doc:app'].comment = "Generate docs for the app -- also availble doc:rails, doc:guides, doc:plugins (options: TEMPLATE=/rdoc-template.rb, TITLE=\"Custom Title\")"

  # desc 'Generate documentation for the Rails framework.'
  RDocTaskWithoutDescriptions.new("rails") { |rdoc|
    rdoc.rdoc_dir = 'doc/api'
    rdoc.template = "#{ENV['template']}.rb" if ENV['template']
    rdoc.title    = "Rails Framework Documentation"
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')

    gem_path('actionmailer') do |actionmailer|
      %w(README.rdoc CHANGELOG MIT-LICENSE lib/action_mailer/base.rb).each do |file|
        rdoc.rdoc_files.include("#{actionmailer}/#{file}")
      end
    end

    gem_path('actionpack') do |actionpack|
      %w(README.rdoc CHANGELOG MIT-LICENSE lib/action_controller/**/*.rb lib/action_view/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{actionpack}/#{file}")
      end
    end

    gem_path('activemodel') do |activemodel|
      %w(README.rdoc CHANGELOG MIT-LICENSE lib/active_model/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activemodel}/#{file}")
      end
    end

    gem_path('activerecord') do |activerecord|
      %w(README.rdoc CHANGELOG lib/active_record/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activerecord}/#{file}")
      end
    end

    gem_path('activeresource') do |activeresource|
      %w(README.rdoc CHANGELOG lib/active_resource.rb lib/active_resource/*).each do |file|
        rdoc.rdoc_files.include("#{activeresource}/#{file}")
      end
    end

    gem_path('activesupport') do |activesupport|
      %w(README.rdoc CHANGELOG lib/active_support/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activesupport}/#{file}")
      end
    end

    gem_path('railties') do |railties|
      %w(README.rdoc CHANGELOG lib/{*.rb,commands/*.rb,generators/*.rb}).each do |file|
        rdoc.rdoc_files.include("#{railties}/#{file}")
      end
    end
  }

  plugins = FileList['vendor/plugins/**'].collect { |plugin| File.basename(plugin) }

  # desc "Generate documentation for all installed plugins"
  task :plugins => plugins.collect { |plugin| "doc:plugins:#{plugin}" }

  # desc "Remove plugin documentation"
  task :clobber_plugins do
    rm_rf 'doc/plugins' rescue nil
  end

  # desc "Generate Rails Guides"
  task :guides do
    # FIXME: Reaching outside lib directory is a bad idea
    require File.expand_path('../../../../guides/rails_guides', __FILE__)
    RailsGuides::Generator.new(Rails.root.join("doc/guides")).generate
  end

  namespace :plugins do
    # Define doc tasks for each plugin
    plugins.each do |plugin|
      # desc "Generate documentation for the #{plugin} plugin"
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
