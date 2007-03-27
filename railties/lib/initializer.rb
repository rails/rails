require 'logger'
require 'set'
require 'pathname'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'railties_path'
require 'rails/version'


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
      @loaded_plugins = []
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
    # * #initialize_dependency_mechanism
    # * #initialize_breakpoints
    # * #initialize_whiny_nils
    # * #initialize_framework_settings
    # * #load_environment
    # * #load_plugins
    # * #load_observers
    # * #initialize_routing
    #
    # (Note that #load_environment is invoked twice, once at the start and
    # once at the end, to support the legacy configuration style where the
    # environment could overwrite the defaults directly, instead of via the
    # Configuration instance.
    def process
      check_ruby_version
      set_load_path
      set_connection_adapters

      require_frameworks
      set_autoload_paths
      load_environment

      initialize_encoding
      initialize_database
      initialize_logger
      initialize_framework_logging
      initialize_framework_views
      initialize_dependency_mechanism
      initialize_breakpoints
      initialize_whiny_nils
      initialize_temporary_directories
      initialize_framework_settings

      # Support for legacy configuration style where the environment
      # could overwrite anything set from the defaults/global through
      # the individual base class configurations.
      load_environment

      add_support_load_paths

      load_plugins

      # Observers are loaded after plugins in case Observers or observed models are modified by plugins.
      load_observers

      # Routing must be initialized after plugins to allow the former to extend the routes
      initialize_routing

      # the framework is now fully initialized
      after_initialize
    end

    # Check for valid Ruby version
    # This is done in an external file, so we can use it
    # from the `rails` program as well without duplication.
    def check_ruby_version
      require 'ruby_version_check'
    end

    # Set the <tt>$LOAD_PATH</tt> based on the value of
    # Configuration#load_paths. Duplicates are removed.
    def set_load_path
      load_paths = configuration.load_paths + configuration.framework_paths
      load_paths.reverse_each { |dir| $LOAD_PATH.unshift(dir) if File.directory?(dir) }
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files, and
    # the load_once paths.
    def set_autoload_paths
      Dependencies.load_paths = configuration.load_paths.uniq
      Dependencies.load_once_paths = configuration.load_once_paths.uniq

      extra = Dependencies.load_once_paths - Dependencies.load_paths
      unless extra.empty?
        abort <<-end_error
          load_once_paths must be a subset of the load_paths.
          Extra items in load_once_paths: #{extra * ','}
        end_error
      end

      # Freeze the arrays so future modifications will fail rather than do nothing mysteriously
      configuration.load_once_paths.freeze
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

    # Add the load paths used by support functions such as the info controller
    def add_support_load_paths
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
    # If an array of plugin names is specified in config.plugins, the plugins
    # will be loaded in that order. Otherwise, plugins are loaded in alphabetical
    # order.
    def load_plugins
      if configuration.plugins.nil?
        # a nil value implies we don't care about plugins; load 'em all in a reliable order
        find_plugins(configuration.plugin_paths).sort.each { |path| load_plugin path }
      elsif !configuration.plugins.empty?
        # we've specified a config.plugins array, so respect that order
        plugin_paths = find_plugins(configuration.plugin_paths)
        configuration.plugins.each do |name|
          path = plugin_paths.find { |p| File.basename(p) == name }
          raise(LoadError, "Cannot find the plugin '#{name}'!") if path.nil?
          load_plugin path
        end
      end
      $LOAD_PATH.uniq!
    end

    # Loads the environment specified by Configuration#environment_path, which
    # is typically one of development, testing, or production.
    def load_environment
      silence_warnings do
        config = configuration
        constants = self.class.constants
        
        eval(IO.read(configuration.environment_path), binding, configuration.environment_path)
        
        (self.class.constants - constants).each do |const|
          Object.const_set(const, self.class.const_get(const))
        end
      end
    end

    def load_observers
      ActiveRecord::Base.instantiate_observers
    end

    # This initialzation sets $KCODE to 'u' to enable the multibyte safe operations.
    # Plugin authors supporting other encodings should override this behaviour and
    # set the relevant +default_charset+ on ActionController::Base
    def initialize_encoding
      $KCODE='u'
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
      ActionController::Routing.controller_paths = configuration.controller_paths
      ActionController::Routing::Routes.reload
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

    def initialize_temporary_directories
      if configuration.frameworks.include?(:action_controller)
        session_path = "#{configuration.root_path}/tmp/sessions/"
        ActionController::Base.session_options[:tmpdir] = File.exist?(session_path) ? session_path : Dir::tmpdir

        cache_path = "#{configuration.root_path}/tmp/cache/"
        if File.exist?(cache_path)
          ActionController::Base.fragment_cache_store = :file_store, cache_path
        end
      end
    end

    # Initializes framework-specific settings for each of the loaded frameworks
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

    # Fires the user-supplied after_initialize block (Configuration#after_initialize)
    def after_initialize
      configuration.after_initialize_block.call if configuration.after_initialize_block
    end

    protected
      # Return a list of plugin paths within base_path.  A plugin path is
      # a directory that contains either a lib directory or an init.rb file.
      # This recurses into directories which are not plugin paths, so you
      # may organize your plugins within the plugin path.
      def find_plugins(*base_paths)
        base_paths.flatten.inject([]) do |plugins, base_path|
          Dir.glob(File.join(base_path, '*')).each do |path|
            if plugin_path?(path)
              plugins << path if plugin_enabled?(path)
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

      def plugin_enabled?(path)
        configuration.plugins.nil? || configuration.plugins.include?(File.basename(path))
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

        # Add lib to load path *after* the application lib, to allow
        # application libraries to override plugin libraries.
        if has_lib
          application_lib_index = $LOAD_PATH.index(File.join(RAILS_ROOT, "lib")) || 0
          $LOAD_PATH.insert(application_lib_index + 1, lib_path)
          Dependencies.load_paths << lib_path
          Dependencies.load_once_paths << lib_path
        end

        # Allow plugins to reference the current configuration object
        config = configuration
	
        # Add to set of loaded plugins before 'name' collapsed in eval.
        loaded_plugins << name

        # Evaluate init.rb.
        silence_warnings { eval(IO.read(init_path), binding, init_path) } if has_init

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
    # The application's base directory.
    attr_reader :root_path

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

    # An array of paths from which Rails will automatically load from only once.
    # All elements of this array must also be in +load_paths+.
    attr_accessor :load_once_paths

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

    # The list of plugins to load. If this is set to <tt>nil</tt>, all plugins will
    # be loaded. If this is set to <tt>[]</tt>, no plugins will be loaded. Otherwise,
    # plugins will be loaded in the order specified.
    attr_accessor :plugins

    # The path to the root of the plugins directory. By default, it is in
    # <tt>vendor/plugins</tt>.
    attr_accessor :plugin_paths

    # Create a new Configuration instance, initialized with the default
    # values.
    def initialize
      set_root_path!

      self.frameworks                   = default_frameworks
      self.load_paths                   = default_load_paths
      self.load_once_paths              = default_load_once_paths
      self.log_path                     = default_log_path
      self.log_level                    = default_log_level
      self.view_path                    = default_view_path
      self.controller_paths             = default_controller_paths
      self.cache_classes                = default_cache_classes
      self.breakpoint_server            = default_breakpoint_server
      self.whiny_nils                   = default_whiny_nils
      self.plugins                      = default_plugins
      self.plugin_paths                 = default_plugin_paths
      self.database_configuration_file  = default_database_configuration_file

      for framework in default_frameworks
        self.send("#{framework}=", Rails::OrderedOptions.new)
      end
    end

    # Set the root_path to RAILS_ROOT and canonicalize it.
    def set_root_path!
      raise 'RAILS_ROOT is not set' unless defined?(::RAILS_ROOT)
      raise 'RAILS_ROOT is not a directory' unless File.directory?(::RAILS_ROOT)

      @root_path =
        # Pathname is incompatible with Windows, but Windows doesn't have
        # real symlinks so File.expand_path is safe.
        if RUBY_PLATFORM =~ /(:?mswin|mingw)/
          File.expand_path(::RAILS_ROOT)

        # Otherwise use Pathname#realpath which respects symlinks.
        else
          Pathname.new(::RAILS_ROOT).realpath.to_s
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

    # Sets a block which will be executed after rails has been fully initialized.
    # Useful for per-environment configuration which depends on the framework being
    # fully initialized.
    def after_initialize(&after_initialize_block)
      @after_initialize_block = after_initialize_block
    end

    # Returns the block set in Configuration#after_initialize
    def after_initialize_block
      @after_initialize_block
    end

    # Add a preparation callback that will run before every request in development
    # mode, or before the first request in production.
    #
    # See Dispatcher#to_prepare.
    def to_prepare(&callback)
      require 'dispatcher' unless defined?(::Dispatcher)
      Dispatcher.to_prepare(&callback)
    end

    def builtin_directories
      # Include builtins only in the development environment.
      (environment == 'development') ? Dir["#{RAILTIES_PATH}/builtin/*/"] : []
    end

    def framework_paths
      # TODO: Don't include dirs for frameworks that are not used
      %w(
        railties
        railties/lib
        actionpack/lib
        activesupport/lib
        activerecord/lib
        actionmailer/lib
        actionwebservice/lib
      ).map { |dir| "#{framework_root_path}/#{dir}" }.select { |dir| File.directory?(dir) }
    end

    private
      def framework_root_path
        defined?(::RAILS_FRAMEWORK_ROOT) ? ::RAILS_FRAMEWORK_ROOT : "#{root_path}/vendor/rails"
      end

      def default_frameworks
        [ :active_record, :action_controller, :action_view, :action_mailer, :action_web_service ]
      end

      def default_load_paths
        paths = ["#{root_path}/test/mocks/#{environment}"]

        # Add the app's controller directory
        paths.concat(Dir["#{root_path}/app/controllers/"])

        # Then components subdirectories.
        paths.concat(Dir["#{root_path}/components/[_a-z]*"])

        # Followed by the standard includes.
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
        ).map { |dir| "#{root_path}/#{dir}" }.select { |dir| File.directory?(dir) }

        paths.concat builtin_directories
      end

      # Doesn't matter since plugins aren't in load_paths yet.
      def default_load_once_paths
        []
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
        paths = [ File.join(root_path, 'app', 'controllers'), File.join(root_path, 'components') ]
        paths.concat builtin_directories
        paths
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

      def default_plugins
        nil
      end

      def default_plugin_paths
        ["#{root_path}/vendor/plugins"]
      end
  end
end

# Needs to be duplicated from Active Support since its needed before Active
# Support is available. Here both Options and Hash are namespaced to prevent
# conflicts with other implementations AND with the classes residing in ActiveSupport.
class Rails::OrderedOptions < Array #:nodoc:
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
