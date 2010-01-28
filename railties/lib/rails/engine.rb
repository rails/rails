require 'active_support/core_ext/module/delegation'
require 'rails/railtie'

module Rails
  class Engine < Railtie
    autoload :Configurable,  "rails/engine/configurable"
    autoload :Configuration, "rails/engine/configuration"

    class << self
      attr_accessor :called_from

      alias :engine_name  :railtie_name
      alias :engine_names :railtie_names

      def inherited(base)
        unless abstract_railtie?(base)
          base.called_from = begin
            call_stack = caller.map { |p| p.split(':').first }
            File.dirname(call_stack.detect { |p| p !~ %r[railties/lib/rails|rack/lib/rack] })
          end
        end

        super
      end

      def find_root_with_flag(flag, default=nil)
        root_path = self.called_from

        while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
          parent = File.dirname(root_path)
          root_path = parent != root_path && parent
        end

        root = File.exist?("#{root_path}/#{flag}") ? root_path : default
        raise "Could not find root path for #{self}" unless root

        RUBY_PLATFORM =~ /(:?mswin|mingw)/ ?
          Pathname.new(root).expand_path : Pathname.new(root).realpath
      end
    end

    delegate :middleware, :paths, :root, :to => :config

    def load_tasks
      super 
      config.paths.lib.tasks.to_a.sort.each { |ext| load(ext) }
    end

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path, :before => :bootstrap_load_path do
      config.load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files,
    # and the load_once paths.
    initializer :set_autoload_paths, :before => :bootstrap_load_path do |app|
      ActiveSupport::Dependencies.load_paths.unshift(*config.load_paths)

      if reloadable?(app)
        ActiveSupport::Dependencies.load_once_paths.unshift(*config.load_once_paths)
      else
        ActiveSupport::Dependencies.load_once_paths.unshift(*config.load_paths)
      end

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.load_paths.freeze
      config.load_once_paths.freeze
    end

    initializer :add_routing_paths do |app|
      paths.config.routes.to_a.each do |route|
        app.routes_reloader.paths.unshift(route) if File.exists?(route)
      end
    end

    initializer :add_routing_namespaces do |app|
      paths.app.controllers.to_a.each do |load_path|
        load_path = File.expand_path(load_path)
        Dir["#{load_path}/*/*_controller.rb"].collect do |path|
          namespace = File.dirname(path).sub(/#{load_path}\/?/, '')
          app.routes.controller_namespaces << namespace unless namespace.empty?
        end
      end
    end

    # I18n load paths are a special case since the ones added
    # later have higher priority.
    initializer :add_locales do
      config.i18n.engines_load_path.concat(paths.config.locales.to_a)
    end

    initializer :add_view_paths do
      views = paths.app.views.to_a
      ActionController::Base.view_paths.unshift(*views) if defined?(ActionController)
      ActionMailer::Base.view_paths.unshift(*views)     if defined?(ActionMailer)
    end

    initializer :add_metals do |app|
      app.metal_loader.paths.unshift(*paths.app.metals.to_a)
    end

    initializer :load_application_initializers do
      paths.config.initializers.to_a.sort.each do |initializer|
        load(initializer)
      end
    end

    initializer :load_application_classes do |app|
      next if $rails_rake_task

      if app.config.cache_classes
        config.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}\/(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end

  protected

    def reloadable?(app)
      app.config.reload_engines
    end
  end
end