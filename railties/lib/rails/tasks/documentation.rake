require 'rdoc/task'

# Monkey-patch to remove redoc'ing and clobber descriptions to cut down on rake -T noise
class RDocTaskWithoutDescriptions < RDoc::Task
  include ::Rake::DSL

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
    rdoc.options << '--line-numbers'
    rdoc.options << '--charset' << 'utf-8'
    rdoc.rdoc_files.include('README.rdoc')
    rdoc.rdoc_files.include('app/**/*.rb')
    rdoc.rdoc_files.include('lib/**/*.rb')
  }
  Rake::Task['doc:app'].comment = "Generate docs for the app -- also available doc:rails, doc:guides (options: TEMPLATE=/rdoc-template.rb, TITLE=\"Custom Title\")"

  # desc 'Generate documentation for the Rails framework.'
  RDocTaskWithoutDescriptions.new("rails") { |rdoc|
    rdoc.rdoc_dir = 'doc/api'
    rdoc.template = "#{ENV['template']}.rb" if ENV['template']
    rdoc.title    = "Rails Framework Documentation"
    rdoc.options << '--line-numbers'

    gem_path('rails') do |rails|
      rdoc.options << '-m' << "#{rails}/README.rdoc"
    end

    gem_path('actionmailer') do |actionmailer|
      %w(README.rdoc CHANGELOG.md MIT-LICENSE lib/action_mailer/base.rb).each do |file|
        rdoc.rdoc_files.include("#{actionmailer}/#{file}")
      end
    end

    gem_path('actionpack') do |actionpack|
      %w(README.rdoc CHANGELOG.md MIT-LICENSE lib/action_controller/**/*.rb lib/action_view/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{actionpack}/#{file}")
      end
    end

    gem_path('activemodel') do |activemodel|
      %w(README.rdoc CHANGELOG.md MIT-LICENSE lib/active_model/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activemodel}/#{file}")
      end
    end

    gem_path('activerecord') do |activerecord|
      %w(README.rdoc CHANGELOG.md lib/active_record/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activerecord}/#{file}")
      end
    end

    gem_path('activesupport') do |activesupport|
      %w(README.rdoc CHANGELOG.md lib/active_support/**/*.rb).each do |file|
        rdoc.rdoc_files.include("#{activesupport}/#{file}")
      end
    end

    gem_path('railties') do |railties|
      %w(README.rdoc CHANGELOG.md lib/{*.rb,commands/*.rb,generators/*.rb}).each do |file|
        rdoc.rdoc_files.include("#{railties}/#{file}")
      end
    end
  }

  # desc "Generate Rails Guides"
  task :guides do
    # FIXME: Reaching outside lib directory is a bad idea
    require File.expand_path('../../../../guides/rails_guides', __FILE__)
    RailsGuides::Generator.new(Rails.root.join("doc/guides")).generate
  end
end
