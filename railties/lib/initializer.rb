require 'logger'
require 'set'
require File.join(File.dirname(__FILE__), 'railties_path')

RAILS_ENV = (ENV['RAILS_ENV'] || 'development').dup unless defined?(RAILS_ENV)

module Rails
  # The Initializer is responsible for processing the Rails configuration, such
  # as setting the $LOAD_PATH, requiring the right frameworks, initializing
  # logging, and more. It can be run either as a single command that'll just
  # use the default configuration, like this:
  #
  #   Rails::Initializer.run
  #
  # But normally it's more interesting to pass in a custom configuration
  # through the block running:
  #
  #   Rails::Initializer.run do |config|
  #     config.frameworks -= [ :action_web_service ]
  #   end
  #
  # This will use the default configuration options from Rails::Configuration,
  # but allow for overwriting on select areas.
  class Initializer
    # The Configuration instance used by this Initializer instance.
    attr_reader :configuration

    # The set of loaded plugins.
    attr_reader :loaded_plugins

    # Runs the initializer. By default, this will invoke the #process method,
    # which simply executes all of the initialization routines. Alternately,
    # you can specify explicitly which initialization routine you want:
    #
    #   Rails::Initializer.run(:set_load_path)
    #
    # This is useful if you only want the load path initialized, without
    # incuring the overhead of completely loading the entire environment. 
    def self.run(command = :process, configuration = Configuration.new)
      yield configuration if block_given?
      initializer = new configuration
      initializer.send(command)
      initializer
    end
    
    # Create a new Initializer instance that references the given Configuration
    # instance.
    def initialize(configuration)
      @configuration = configuration
      @loaded_plugins = Set.new
    end

    # Sequentially step through all of the available initialization routines,
    # in order:
    #
    # * #set_load_path
    # * #set_connection_adapters
    # * #require_frameworks
    # * #load_environment
    # * #initialize_database
    # * #initialize_logger
    # * #initialize_framework_logging
    # * #initialize_framework_views
    # * #initialize_routing
    # * #initialize_dependency_mechanism
    # * #initialize_breakpoints
    # * #initialize_whiny_nils
    # * #initialize_framework_settings
    # * #load_environment
    # * #load_plugins
    #
    # (Note that #load_environment is invoked twice, once at the start and
    # once at the end, to support the legacy configuration style where the
    # environment could overwrite the defaults directly, instead of via the
    # Configuration instance. 
    def process
      set_load_path
      set_connection_adapters

      require_frameworks
      load_environment

      initialize_database
      initialize_logger
      initialize_framework_logging
      initialize_framework_views
      initialize_dependency_mechanism
      initialize_breakpoints
      initialize_whiny_nils
      
      initialize_framework_settings
      
      # Support for legacy configuration style where the environment
      # could overwrite anything set from the defaults/global through
      # the individual base class configurations.
      load_environment
      
      load_framework_info

      load_plugins

      # Routing must be initialized after plugins to allow the former to extend the routes
      initialize_routing
    end
    
    # Set the <tt>$LOAD_PATH</tt> based on the value of
    # Configuration#load_paths. Duplicates are removed.
    def set_load_path
      configuration.load_paths.reverse.each { |dir| $LOAD_PATH.unshift(dir) if File.directory?(dir) }
      $LOAD_PATH.uniq!
    end
    
    # Sets the +RAILS_CONNECTION_ADAPTERS+ constant based on the value of
    # Configuration#connection_adapters. This constant is used to determine
    # which database adapters should be loaded (by default, all adapters are
    # loaded).
    def set_connection_adapters
      Object.const_set("RAILS_CONNECTION_ADAPTERS", configuration.connection_adapters) if configuration.connection_adapters
    end
    
    # Requires all frameworks specified by the Configuration#frameworks
    # list. By default, all frameworks (ActiveRecord, ActiveSupport,
    # ActionPack, ActionMailer, and ActionWebService) are loaded.
    def require_frameworks
      configuration.frameworks.each { |framework| require(framework.to_s) }
    end
    
    # Loads Rails::VERSION and Rails::Info.
    # TODO: Make this work via dependencies.rb/const_missing instead.
    def load_framework_info
      require 'rails_info'
    end

    # Loads all plugins in <tt>config.plugin_paths</tt>.  <tt>plugin_paths</tt>
    # defaults to <tt>vendor/plugins</tt> but may also be set to a list of
    # paths, such as
    #   config.plugin_paths = ['lib/plugins', 'vendor/plugins']
    #
    # Each plugin discovered in <tt>plugin_paths</tt> is initialized:
    # * add its +lib+ directory, if present, to the beginning of the load path
    # * evaluate <tt>init.rb</tt> if present
    #
    # After all plugins are loaded, duplicates are removed from the load path.
    def load_plugins
      find_plugins(configuration.plugin_paths).each { |path| load_plugin path }
      $LOAD_PATH.uniq!
    end

    # Loads the environment specified by Configuration#environment_path, which
    # is typically one of development, testing, or production.
    def load_environment
      silence_warnings do
        config = configuration
        constants = self.class.constants
        eval(IO.read(configuration.environment_path), binding)
        (self.class.constants - constants).each do |const|
          Object.const_set(const, self.class.const_get(const))
        end
      end
    end
    
    # This initialization routine does nothing unless <tt>:active_record</tt>
    # is one of the frameworks to load (Configuration#frameworks). If it is,
    # this sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    def initialize_database
      return unless configuration.frameworks.include?(:active_record)
      ActiveRecord::Base.configurations = configuration.database_configuration
      ActiveRecord::Base.establish_connection
    end
    
    # If the +RAILS_DEFAULT_LOGGER+ constant is already set, this initialization
    # routine does nothing. If the constant is not set, and Configuration#logger
    # is not +nil+, this also does nothing. Otherwise, a new logger instance
    # is created at Configuration#log_path, with a default log level of
    # Configuration#log_level.
    #
    # If the log could not be created, the log will be set to output to
    # +STDERR+, with a log level of +WARN+.
    def initialize_logger
      # if the environment has explicitly defined a logger, use it
      return if defined?(RAILS_DEFAULT_LOGGER)

      unless logger = configuration.logger
        begin
          logger = Logger.new(configuration.log_path)
          logger.level = Logger.const_get(configuration.log_level.to_s.upcase)
        rescue StandardError
          logger = Logger.new(STDERR)
          logger.level = Logger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{configuration.log_path} exists and is chmod 0666. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
        end
      end
      
      silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", logger }
    end
    
    # Sets the logger for ActiveRecord, ActionController, and ActionMailer
    # (but only for those frameworks that are to be loaded). If the framework's
    # logger is already set, it is not changed, otherwise it is set to use
    # +RAILS_DEFAULT_LOGGER+.
    def initialize_framework_logging
      for framework in ([ :active_record, :action_controller, :action_mailer ] & configuration.frameworks)
        framework.to_s.camelize.constantize.const_get("Base").logger ||= RAILS_DEFAULT_LOGGER
      end
    end
    
    # Sets the +template_root+ for ActionController::Base and ActionMailer::Base
    # (but only for those frameworks that are to be loaded). If the framework's
    # +template_root+ has already been set, it is not changed, otherwise it is
    # set to use Configuration#view_path.
    def initialize_framework_views
      for framework in ([ :action_controller, :action_mailer ] & configuration.frameworks)
        framework.to_s.camelize.constantize.const_get("Base").template_root ||= configuration.view_path
      end
    end

    # If ActionController is not one of the loaded frameworks (Configuration#frameworks)
    # this does nothing. Otherwise, it loads the routing definitions and sets up
    # loading module used to lazily load controllers (Configuration#controller_paths).
    def initialize_routing
      return unless configuration.frameworks.include?(:action_controller)
      ActionController::Routing::Routes.reload
      Object.const_set "Controllers", Dependencies::LoadingModule.root(*configuration.controller_paths)
    end
    
    # Sets the dependency loading mechanism based on the value of
    # Configuration#cache_classes.
    def initialize_dependency_mechanism
      Dependencies.mechanism = configuration.cache_classes ? :require : :load
    end
    
    # Sets the +BREAKPOINT_SERVER_PORT+ if Configuration#breakpoint_server
    # is true.
    def initialize_breakpoints
      silence_warnings { Object.const_set("BREAKPOINT_SERVER_PORT", 42531) if configuration.breakpoint_server }
    end

    # Loads support for "whiny nil" (noisy warnings when methods are invoked
    # on +nil+ values) if Configuration#whiny_nils is true.
    def initialize_whiny_nils
      require('active_support/whiny_nil') if configuration.whiny_nils
    end

    # Initialize framework-specific settings for each of the loaded frameworks
    # (Configuration#frameworks). The available settings map to the accessors
    # on each of the corresponding Base classes.
    def initialize_framework_settings
      configuration.frameworks.each do |framework|
        base_class = framework.to_s.camelize.constantize.const_get("Base")

        configuration.send(framework).each do |setting, value|
          base_class.send("#{setting}=", value)
        end
      end
    end

    protected
      # Return a list of plugin paths within base_path.  A plugin path is
      # a directory that contains either a lib directory or an init.rb file.
      # This recurses into directories which are not plugin paths, so you
      # may organize your plugins which the plugin path.
      def find_plugins(*base_paths)
        base_paths.flatten.inject([]) do |plugins, base_path|
          Dir.glob(File.join(base_path, '*')).each do |path|
            if plugin_path?(path)
              plugins << path
            elsif File.directory?(path)
              plugins += find_plugins(path)
            end
          end
          plugins
        end
      end

      def plugin_path?(path)
        File.directory?(path) and (File.directory?(File.join(path, 'lib')) or File.file?(File.join(path, 'init.rb')))
      end

      # Load the plugin at <tt>path</tt> unless already loaded.
      #
      # Each plugin is initialized:
      # * add its +lib+ directory, if present, to the beginning of the load path
      # * evaluate <tt>init.rb</tt> if present
      #
      # Returns <tt>true</tt> if the plugin is successfully loaded or
      # <tt>false</tt> if it is already loaded (similar to Kernel#require).
      # Raises <tt>LoadError</tt> if the plugin is not found.
      def load_plugin(directory)
        name = File.basename(directory)
        return false if loaded_plugins.include?(name)

        # Catch nonexistent and empty plugins.
        raise LoadError, "No such plugin: #{directory}" unless plugin_path?(directory)

        lib_path  = File.join(directory, 'lib')
        init_path = File.join(directory, 'init.rb')
        has_lib   = File.directory?(lib_path)
        has_init  = File.file?(init_path)

        # Add lib to load path.
        $LOAD_PATH.unshift(lib_path) if has_lib
        
        # Allow plugins to reference the current configuration object
        config = configuration 

        # Evaluate init.rb.
        silence_warnings { eval(IO.read(init_path), binding, init_path) } if has_init

        # Add to set of loaded plugins.
        loaded_plugins << name
        true
      end
  end

  # The Configuration class holds all the parameters for the Initializer and
  # ships with defaults that suites most Rails applications. But it's possible
  # to overwrite everything. Usually, you'll create an Configuration file
  # implicitly through the block running on the Initializer, but it's also
  # possible to create the Configuration instance in advance and pass it in
  # like this:
  #
  #   config = Rails::Configuration.new
  #   Rails::Initializer.run(:process, config)
  class Configuration
    # A stub for setting options on ActionController::Base
    attr_accessor :action_controller
    
    # A stub for setting options on ActionMailer::Base
    attr_accessor :action_mailer
    
    # A stub for setting options on ActionView::Base
    attr_accessor :action_view
    
    # A stub for setting options on ActionWebService::Base
    attr_accessor :action_web_service
    
    # A stub for setting options on ActiveRecord::Base
    attr_accessor :active_record
    
    # Whether or not to use the breakpoint server (boolean)
    attr_accessor :breakpoint_server
    
    # Whether or not classes should be cached (set to false if you want
    # application classes to be reloaded on each request)
    attr_accessor :cache_classes
    
    # The list of connection adapters to load. (By default, all connection
    # adapters are loaded. You can set this to be just the adapter(s) you
    # will use to reduce your application's load time.)
    attr_accessor :connection_adapters
    
    # The list of paths that should be searched for controllers. (Defaults
    # to <tt>app/controllers</tt> and <tt>components</tt>.)
    attr_accessor :controller_paths

    # The path to the database configuration file to use. (Defaults to
    # <tt>config/database.yml</tt>.)
    attr_accessor :database_configuration_file
    
    # The list of rails framework components that should be loaded. (Defaults
    # to <tt>:active_record</tt>, <tt>:action_controller</tt>,
    # <tt>:action_view</tt>, <tt>:action_mailer</tt>, and
    # <tt>:action_web_service</tt>).
    attr_accessor :frameworks
    
    # An array of additional paths to prepend to the load path. By default,
    # all +app+, +lib+, +vendor+ and mock paths are included in this list.
    attr_accessor :load_paths
    
    # The log level to use for the default Rails logger. In production mode,
    # this defaults to <tt>:info</tt>. In development mode, it defaults to
    # <tt>:debug</tt>.
    attr_accessor :log_level
    
    # The path to the log file to use. Defaults to log/#{environment}.log
    # (e.g. log/development.log or log/production.log).
    attr_accessor :log_path
    
    # The specific logger to use. By default, a logger will be created and
    # initialized using #log_path and #log_level, but a programmer may
    # specifically set the logger to use via this accessor and it will be
    # used directly.
    attr_accessor :logger
    
    # The root of the application's views. (Defaults to <tt>app/views</tt>.)
    attr_accessor :view_path
    
    # Set to +true+ if you want to be warned (noisily) when you try to invoke
    # any method of +nil+. Set to +false+ for the standard Ruby behavior.
    attr_accessor :whiny_nils
    
    # The path to the root of the plugins directory. By default, it is in
    # <tt>vendor/plugins</tt>.
    attr_accessor :plugin_paths

    # Create a new Configuration instance, initialized with the default
    # values.
    def initialize
      self.frameworks                   = default_frameworks
      self.load_paths                   = default_load_paths
      self.log_path                     = default_log_path
      self.log_level                    = default_log_level
      self.view_path                    = default_view_path
      self.controller_paths             = default_controller_paths
      self.cache_classes                = default_cache_classes
      self.breakpoint_server            = default_breakpoint_server
      self.whiny_nils                   = default_whiny_nils
      self.plugin_paths                 = default_plugin_paths
      self.database_configuration_file  = default_database_configuration_file

      for framework in default_frameworks
        self.send("#{framework}=", OrderedOptions.new)
      end
    end
    
    # Loads and returns the contents of the #database_configuration_file. The
    # contents of the file are processed via ERB before being sent through
    # YAML::load.
    def database_configuration
      YAML::load(ERB.new(IO.read(database_configuration_file)).result)
    end
    
    # The path to the current environment's file (development.rb, etc.). By
    # default the file is at <tt>config/environments/#{environment}.rb</tt>.
    def environment_path
      "#{root_path}/config/environments/#{environment}.rb"
    end

    # Return the currently selected environment. By default, it returns the
    # value of the +RAILS_ENV+ constant.
    def environment
      ::RAILS_ENV
    end

    private
      def root_path
        ::RAILS_ROOT
      end

      def default_frameworks
        [ :active_record, :action_controller, :action_view, :action_mailer, :action_web_service ]
      end
    
      def default_load_paths
        paths = ["#{root_path}/test/mocks/#{environment}"]

        # Then model subdirectories.
        # TODO: Don't include .rb models as load paths
        paths.concat(Dir["#{root_path}/app/models/[_a-z]*"])
        paths.concat(Dir["#{root_path}/components/[_a-z]*"])

        # Followed by the standard includes.
        # TODO: Don't include dirs for frameworks that are not used
        paths.concat %w(
          app 
          app/models 
          app/controllers
          app/helpers
          app/services
          app/apis 
          components 
          config 
          lib 
          vendor 
          vendor/rails/railties
          vendor/rails/railties/lib
          vendor/rails/actionpack/lib
          vendor/rails/activesupport/lib
          vendor/rails/activerecord/lib
          vendor/rails/actionmailer/lib
          vendor/rails/actionwebservice/lib
        ).map { |dir| "#{root_path}/#{dir}" }.select { |dir| File.directory?(dir) }
      end

      def default_log_path
        File.join(root_path, 'log', "#{environment}.log")
      end
      
      def default_log_level
        environment == 'production' ? :info : :debug
      end
      
      def default_database_configuration_file
        File.join(root_path, 'config', 'database.yml')
      end
      
      def default_view_path
        File.join(root_path, 'app', 'views')
      end
      
      def default_controller_paths
        [ File.join(root_path, 'app', 'controllers'), File.join(root_path, 'components'), File.join(RAILTIES_PATH, 'builtin', 'controllers') ]
      end
      
      def default_dependency_mechanism
        :load
      end
      
      def default_cache_classes
        false
      end
      
      def default_breakpoint_server
        false
      end
      
      def default_whiny_nils
        false
      end

      def default_plugin_paths
        ["#{root_path}/vendor/plugins"]
      end
  end
end

# Needs to be duplicated from Active Support since its needed before Active
# Support is available.
class OrderedOptions < Array # :nodoc:
  def []=(key, value)
    key = key.to_sym

    if pair = find_pair(key)
      pair.pop
      pair << value
    else
      self << [key, value]
    end
  end

  def [](key)
    pair = find_pair(key.to_sym)
    pair ? pair.last : nil
  end

  def method_missing(name, *args)
    if name.to_s =~ /(.*)=$/
      self[$1.to_sym] = args.first
    else
      self[name]
    end
  end

  private
    def find_pair(key)
      self.each { |i| return i if i.first == key }
      return false
    end
end
