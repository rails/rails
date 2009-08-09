module Rails
  class Configuration
    attr_accessor :cache_classes, :load_paths, :eager_load_paths, :framework_paths,
                  :load_once_paths, :gems_dependencies_loaded, :after_initialize_blocks,
                  :frameworks, :framework_root_path, :root_path, :plugin_paths, :plugins,
                  :plugin_loader, :plugin_locators, :gems, :loaded_plugins, :reload_plugins,
                  :i18n, :gems, :whiny_nils, :consider_all_requests_local,
                  :action_controller, :active_record, :action_view, :active_support,
                  :action_mailer, :active_resource,
                  :log_path, :log_level, :logger, :preload_frameworks,
                  :database_configuration_file, :cache_store, :time_zone,
                  :view_path, :metals, :controller_paths, :routes_configuration_file,
                  :eager_load_paths, :dependency_loading, :paths

    def initialize
      set_root_path!

      @framework_paths              = []
      @load_once_paths              = []
      @after_initialize_blocks      = []
      @loaded_plugins               = []
      @dependency_loading           = true
      @eager_load_paths             = default_eager_load_paths
      @load_paths                   = default_load_paths
      @plugin_paths                 = default_plugin_paths
      @frameworks                   = default_frameworks
      @plugin_loader                = default_plugin_loader
      @plugin_locators              = default_plugin_locators
      @gems                         = default_gems
      @i18n                         = default_i18n
      @log_path                     = default_log_path
      @log_level                    = default_log_level
      @cache_store                  = default_cache_store
      @view_path                    = default_view_path
      @controller_paths             = default_controller_paths
      @routes_configuration_file    = default_routes_configuration_file
      @database_configuration_file  = default_database_configuration_file

      for framework in default_frameworks
        self.send("#{framework}=", Rails::OrderedOptions.new)
      end
      self.active_support = Rails::OrderedOptions.new
    end

    def after_initialize(&blk)
      @after_initialize_blocks << blk if blk
    end

    def set_root_path!
      raise 'RAILS_ROOT is not set' unless defined?(RAILS_ROOT)
      raise 'RAILS_ROOT is not a directory' unless File.directory?(RAILS_ROOT)

      self.root_path =
        # Pathname is incompatible with Windows, but Windows doesn't have
        # real symlinks so File.expand_path is safe.
        if RUBY_PLATFORM =~ /(:?mswin|mingw)/
          File.expand_path(RAILS_ROOT)

        # Otherwise use Pathname#realpath which respects symlinks.
        else
          Pathname.new(RAILS_ROOT).realpath.to_s
        end

      @paths = Rails::Application::Root.new(root_path)
      @paths.app                 "app",             :load_path => true
      @paths.app.metals          "app/metal",       :eager_load => true
      @paths.app.models          "app/models",      :eager_load => true
      @paths.app.controllers     "app/controllers", builtin_directories, :eager_load => true
      @paths.app.helpers         "app/helpers",     :eager_load => true
      @paths.app.services        "app/services",    :load_path => true
      @paths.lib                 "lib",             :load_path => true
      @paths.vendor              "vendor",          :load_path => true
      @paths.vendor.plugins      "vendor/plugins"
      @paths.tmp                 "tmp"
      @paths.tmp.cache           "tmp/cache"
      @paths.config              "config"
      @paths.config.locales      "config/locales"
      @paths.config.environments "config/environments", :glob => "#{RAILS_ENV}.rb"

      RAILS_ROOT.replace root_path
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
      defined?(::RAILS_FRAMEWORK_ROOT) ? ::RAILS_FRAMEWORK_ROOT : "#{root_path}/vendor/rails"
    end

    # TODO: Fix this when there is an application object
    def middleware
      ActionController::Dispatcher.middleware
    end

    # Loads and returns the contents of the #database_configuration_file. The
    # contents of the file are processed via ERB before being sent through
    # YAML::load.
    def database_configuration
      require 'erb'
      YAML::load(ERB.new(IO.read(database_configuration_file)).result)
    end

    def default_routes_configuration_file
      File.join(root_path, 'config', 'routes.rb')
    end

    def default_controller_paths
      paths = [File.join(root_path, 'app', 'controllers')]
      paths.concat builtin_directories
      paths
    end

    def default_cache_store
      if File.exist?("#{root_path}/tmp/cache/")
        [ :file_store, "#{root_path}/tmp/cache/" ]
      else
        :memory_store
      end
    end

    def default_database_configuration_file
      File.join(root_path, 'config', 'database.yml')
    end

    def default_view_path
      File.join(root_path, 'app', 'views')
    end

    def default_eager_load_paths
      %w(
        app/metal
        app/models
        app/controllers
        app/helpers
      ).map { |dir| "#{root_path}/#{dir}" }.select { |dir| File.directory?(dir) }
    end

    def default_load_paths
      paths = []

      # Add the old mock paths only if the directories exists
      paths.concat(Dir["#{root_path}/test/mocks/#{RAILS_ENV}"]) if File.exists?("#{root_path}/test/mocks/#{RAILS_ENV}")

      # Add the app's controller directory
      paths.concat(Dir["#{root_path}/app/controllers/"])

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
      ).map { |dir| "#{root_path}/#{dir}" }.select { |dir| File.directory?(dir) }

      paths.concat builtin_directories
    end

    def builtin_directories
      # Include builtins only in the development environment.
      (RAILS_ENV == 'development') ? Dir["#{RAILTIES_PATH}/builtin/*/"] : []
    end

    def default_log_path
      File.join(root_path, 'log', "#{RAILS_ENV}.log")
    end

    def default_log_level
      RAILS_ENV == 'production' ? :info : :debug
    end

    def default_frameworks
      [ :active_record, :action_controller, :action_view, :action_mailer, :active_resource ]
    end

    def default_plugin_paths
      ["#{root_path}/vendor/plugins"]
    end

    def default_plugin_loader
      require 'rails/plugin/loader'
      Plugin::Loader
    end

    def default_plugin_locators
      require 'rails/plugin/locator'
      locators = []
      locators << Plugin::GemLocator if defined? Gem
      locators << Plugin::FileSystemLocator
    end

    def default_i18n
      i18n = Rails::OrderedOptions.new
      i18n.load_path = []

      if File.exist?(File.join(RAILS_ROOT, 'config', 'locales'))
        i18n.load_path << Dir[File.join(RAILS_ROOT, 'config', 'locales', '*.{rb,yml}')]
        i18n.load_path.flatten!
      end

      i18n
    end

    # Adds a single Gem dependency to the rails application. By default, it will require
    # the library with the same name as the gem. Use :lib to specify a different name.
    #
    #   # gem 'aws-s3', '>= 0.4.0'
    #   # require 'aws/s3'
    #   config.gem 'aws-s3', :lib => 'aws/s3', :version => '>= 0.4.0', \
    #     :source => "http://code.whytheluckystiff.net"
    #
    # To require a library be installed, but not attempt to load it, pass :lib => false
    #
    #   config.gem 'qrp', :version => '0.4.1', :lib => false
    def gem(name, options = {})
      @gems << Rails::GemDependency.new(name, options)
    end

    def default_gems
      []
    end

    def environment_path
      "#{root_path}/config/environments/#{RAILS_ENV}.rb"
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
