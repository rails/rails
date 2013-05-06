begin
  require 'rdoc/task'
rescue LoadError
  # Rubinius installs RDoc as a gem, and for this interpreter "rdoc/task" is
  # available only if the application bundle includes "rdoc" (normally as a
  # dependency of the "sdoc" gem.)
  #
  # If RDoc is not available it is fine that we do not generate the tasks that
  # depend on it. Just be robust to this gotcha and go on.
else
  require 'rails/api/task'

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
    Rails::API::AppTask.new('rails')
  end
end

namespace :doc do
  task :guides do
    # FIXME: Reaching outside lib directory is a bad idea
    require File.expand_path('../../../../../guides/rails_guides', __FILE__)
    RailsGuides::Generator.new(Rails.root.join("doc/guides")).generate
  end
end
