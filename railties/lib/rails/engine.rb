require 'active_support/core_ext/module/delegation'

module Rails
  # TODO Move I18n here
  # TODO Set routes namespaces
  class Engine < Railtie
    class << self
      attr_accessor :called_from

      def original_root
        @original_root ||= find_root_with_file_flag("lib")
      end

      def config
        @config ||= Configuration.new(original_root)
      end

      def inherited(base)
        base.called_from = begin
          call_stack = caller.map { |p| p.split(':').first }
          File.dirname(call_stack.detect { |p| p !~ %r[railties/lib/rails|rack/lib/rack] })
        end

        super
      end

    protected

      def find_root_with_file_flag(flag, default=nil)
        root_path = self.called_from

        while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
          parent = File.dirname(root_path)
          root_path = parent != root_path && parent
        end

        root = File.exist?("#{root_path}/#{flag}") ? root_path : default

        raise "Could not find root path for #{self}" unless root

        RUBY_PLATFORM =~ /(:?mswin|mingw)/ ?
          Pathname.new(root).expand_path :
          Pathname.new(root).realpath
      end
    end

    delegate :config, :to => :'self.class'
    delegate :middleware, :root, :to => :config

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path do
      config.load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files,
    # and the load_once paths.
    initializer :set_autoload_paths do
      ActiveSupport::Dependencies.load_paths.concat(config.load_paths)
      ActiveSupport::Dependencies.load_once_paths.concat(config.load_once_paths)

      extra = ActiveSupport::Dependencies.load_once_paths -
              ActiveSupport::Dependencies.load_paths

      unless extra.empty?
        abort <<-end_error
          load_once_paths must be a subset of the load_paths.
          Extra items in load_once_paths: #{extra * ','}
        end_error
      end

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.load_once_paths.freeze
    end

    initializer :add_routing_files do |app|
      config.paths.config.routes.to_a.each do |route|
        app.route_configuration_files.unshift(route) if File.exists?(route)
      end
    end

    initializer :add_locales do
      config.i18n.load_path.unshift(*config.paths.config.locales.to_a)
    end

    initializer :add_view_paths do
      views = config.paths.app.views.to_a
      ActionController::Base.view_paths.concat(views) if defined?(ActionController)
      ActionMailer::Base.view_paths.concat(views)     if defined?(ActionMailer)
    end

    initializer :load_application_initializers do
      config.paths.config.initializers.each do |initializer|
        load(initializer)
      end
    end

    initializer :load_application_classes do |app|
      next if $rails_rake_task

      if app.config.cache_classes
        config.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end
  end
end