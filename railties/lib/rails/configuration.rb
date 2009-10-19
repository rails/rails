require 'rails/plugin/loader'
require 'rails/plugin/locator'

module Rails
  class Configuration
    attr_accessor :cache_classes, :load_paths,
                  :load_once_paths, :after_initialize_blocks,
                  :frameworks, :framework_root_path, :root, :plugin_paths, :plugins,
                  :plugin_loader, :plugin_locators, :gems, :loaded_plugins, :reload_plugins,
                  :i18n, :gems, :whiny_nils, :consider_all_requests_local,
                  :action_controller, :active_record, :action_view, :active_support,
                  :action_mailer, :active_resource,
                  :log_path, :log_level, :logger, :preload_frameworks,
                  :database_configuration_file, :cache_store, :time_zone,
                  :view_path, :metals, :controller_paths, :routes_configuration_file,
                  :eager_load_paths, :dependency_loading, :paths, :serve_static_assets

    def initialize
      @load_once_paths              = []
      @after_initialize_blocks      = []
      @loaded_plugins               = []
      @dependency_loading           = true
      @serve_static_assets          = true

      for framework in frameworks
        self.send("#{framework}=", Rails::OrderedOptions.new)
      end
      self.active_support = Rails::OrderedOptions.new
    end

    def after_initialize(&blk)
      @after_initialize_blocks << blk if blk
    end

    def root
      @root ||= begin
        call_stack = caller.map { |p| p.split(':').first }
        root_path  = call_stack.detect { |p| p !~ %r[railties/lib/rails] }
        root_path  = File.dirname(root_path)

        while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/config.ru")
          parent = File.dirname(root_path)
          root_path = parent != root_path && parent
        end

        root = File.exist?("#{root_path}/config.ru") ? root_path : Dir.pwd

        RUBY_PLATFORM =~ /(:?mswin|mingw)/ ?
          Pathname.new(root).expand_path :
          Pathname.new(root).realpath
      end
    end

    def root=(root)
      @root = Pathname.new(root).expand_path
    end

    def paths
      @paths ||= begin
        paths = Rails::Application::Root.new(root)
        paths.app                 "app",             :load_path => true
        paths.app.metals          "app/metal",       :eager_load => true
        paths.app.models          "app/models",      :eager_load => true
        paths.app.controllers     "app/controllers", builtin_directories, :eager_load => true
        paths.app.helpers         "app/helpers",     :eager_load => true
        paths.app.services        "app/services",    :load_path => true
        paths.lib                 "lib",             :load_path => true
        paths.vendor              "vendor",          :load_path => true
        paths.vendor.plugins      "vendor/plugins"
        paths.tmp                 "tmp"
        paths.tmp.cache           "tmp/cache"
        paths.config              "config"
        paths.config.locales      "config/locales"
        paths.config.environments "config/environments", :glob => "#{RAILS_ENV}.rb"
        paths
      end
    end

    # Enable threaded mode. Allows concurrent requests to controller actions and
    # multiple database connections. Also disables automatic dependency loading
    # after boot, and disables reloading code on every request, as these are
    # fundamentally incompatible with thread safety.
    def threadsafe!
      self.preload_frameworks = true
      self.cache_classes = true
      self.dependency_loading = false
      self.action_controller.allow_concurrency = true
      self
    end

    def framework_paths
      paths = %w(railties railties/lib activesupport/lib)
      paths << 'actionpack/lib' if frameworks.include?(:action_controller) || frameworks.include?(:action_view)

      [:active_record, :action_mailer, :active_resource, :action_web_service].each do |framework|
        paths << "#{framework.to_s.gsub('_', '')}/lib" if frameworks.include?(framework)
      end

      paths.map { |dir| "#{framework_root_path}/#{dir}" }.select { |dir| File.directory?(dir) }
    end

    def framework_root_path
      defined?(::RAILS_FRAMEWORK_ROOT) ? ::RAILS_FRAMEWORK_ROOT : "#{root}/vendor/rails"
    end

    def middleware
      require 'action_dispatch'
      @middleware ||= ActionDispatch::MiddlewareStack.new
    end

    # Loads and returns the contents of the #database_configuration_file. The
    # contents of the file are processed via ERB before being sent through
    # YAML::load.
    def database_configuration
      require 'erb'
      YAML::load(ERB.new(IO.read(database_configuration_file)).result)
    end

    def routes_configuration_file
      @routes_configuration_file ||= File.join(root, 'config', 'routes.rb')
    end

    def controller_paths
      @controller_paths ||= begin
        paths = [File.join(root, 'app', 'controllers')]
        paths.concat builtin_directories
        paths
      end
    end

    def cache_store
      @cache_store ||= begin
        if File.exist?("#{root}/tmp/cache/")
          [ :file_store, "#{root}/tmp/cache/" ]
        else
          :memory_store
        end
      end
    end

    def database_configuration_file
      @database_configuration_file ||= File.join(root, 'config', 'database.yml')
    end

    def view_path
      @view_path ||= File.join(root, 'app', 'views')
    end

    def eager_load_paths
      @eager_load_paths ||= %w(
        app/metal
        app/models
        app/controllers
        app/helpers
      ).map { |dir| "#{root}/#{dir}" }.select { |dir| File.directory?(dir) }
    end

    def load_paths
      @load_paths ||= begin
        paths = []

        # Add the old mock paths only if the directories exists
        paths.concat(Dir["#{root}/test/mocks/#{RAILS_ENV}"]) if File.exists?("#{root}/test/mocks/#{RAILS_ENV}")

        # Add the app's controller directory
        paths.concat(Dir["#{root}/app/controllers/"])

        # Followed by the standard includes.
        paths.concat %w(
          app
          app/metal
          app/models
          app/controllers
          app/helpers
          app/services
          lib
          vendor
        ).map { |dir| "#{root}/#{dir}" }.select { |dir| File.directory?(dir) }

        paths.concat builtin_directories
      end
    end

    def builtin_directories
      # Include builtins only in the development environment.
      (RAILS_ENV == 'development') ? Dir["#{RAILTIES_PATH}/builtin/*/"] : []
    end

    def log_path
      @log_path ||= File.join(root, 'log', "#{RAILS_ENV}.log")
    end

    def log_level
      @log_level ||= RAILS_ENV == 'production' ? :info : :debug
    end

    def frameworks
      @frameworks ||= [ :active_record, :action_controller, :action_view, :action_mailer, :active_resource ]
    end

    def plugin_paths
      @plugin_paths ||= ["#{root}/vendor/plugins"]
    end

    def plugin_loader
      @plugin_loader ||= begin
        Plugin::Loader
      end
    end

    def plugin_locators
      @plugin_locators ||= begin
        locators = []
        locators << Plugin::GemLocator if defined? Gem
        locators << Plugin::FileSystemLocator
      end
    end

    def i18n
      @i18n ||= begin
        i18n = Rails::OrderedOptions.new
        i18n.load_path = []

        if File.exist?(File.join(root, 'config', 'locales'))
          i18n.load_path << Dir[File.join(root, 'config', 'locales', '*.{rb,yml}')]
          i18n.load_path.flatten!
        end

        i18n
      end
    end

    def environment_path
      "#{root}/config/environments/#{RAILS_ENV}.rb"
    end

    def reload_plugins?
      @reload_plugins
    end

    # Holds generators configuration:
    #
    #   config.generators do |g|
    #     g.orm             :datamapper, :migration => true
    #     g.template_engine :haml
    #     g.test_framework  :rspec
    #   end
    #
    # If you want to disable color in console, do:
    #
    #   config.generators.colorize_logging = false
    #
    def generators
      @generators ||= Generators.new
      if block_given?
        yield @generators
      else
        @generators
      end
    end

    # Allows Notifications queue to be modified.
    #
    #   config.notifications.queue = MyNewQueue.new
    #
    def notifications
      ActiveSupport::Notifications
    end

    class Generators #:nodoc:
      attr_accessor :aliases, :options, :colorize_logging

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @colorize_logging = true
      end

      def method_missing(method, *args)
        method        = method.to_s.sub(/=$/, '').to_sym
        namespace     = args.first.is_a?(Symbol) ? args.shift : nil
        configuration = args.first.is_a?(Hash)   ? args.shift : nil

        @options[:rails][method] = namespace if namespace
        namespace ||= method

        if configuration
          aliases = configuration.delete(:aliases)
          @aliases[namespace].merge!(aliases) if aliases
          @options[namespace].merge!(configuration)
        end
      end
    end
  end
end
