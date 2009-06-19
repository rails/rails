require "pathname"

module Rails
  class Configuration
    attr_accessor :cache_classes, :load_paths, :eager_load_paths, :framework_paths,
                  :load_once_paths, :gems_dependencies_loaded, :after_initialize_blocks,
                  :frameworks, :framework_root_path, :root_path, :plugin_paths, :plugins,
                  :plugin_loader, :plugin_locators, :gems, :loaded_plugins, :reload_plugins,
                  :i18n, :gems

    def initialize
      @framework_paths         = []
      @load_once_paths         = []
      @after_initialize_blocks = []
      @frameworks              = []
      @plugin_paths            = []
      @loaded_plugins          = []
      @plugin_loader           = default_plugin_loader
      @plugin_locators         = default_plugin_locators
      @gems                    = default_gems
      @i18n                    = default_i18n
    end

    def after_initialize(&blk)
      @after_initialize_blocks << blk if blk
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
      require 'action_controller'
      ActionController::Dispatcher.middleware
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

    def reload_plugins?
      @reload_plugins
    end
  end

  class Initializer
    class Error < StandardError ; end

    class Base
      class << self
        def run(&blk)
          define_method(:run, &blk)
        end

        def config=(config)
          @@config = config
        end

        def config
          @@config
        end
        alias configuration config

        def gems_dependencies_loaded
          config.gems_dependencies_loaded
        end

        def plugin_loader
          @plugin_loader ||= configuration.plugin_loader.new(self)
        end
      end

      def gems_dependencies_loaded
        self.class.gems_dependencies_loaded
      end

      def plugin_loader
        self.class.plugin_loader
      end
    end

    class Runner

      attr_reader :names, :initializers
      attr_accessor :config
      alias configuration config

      def initialize(parent = nil)
        @names        = parent ? parent.names.dup        : {}
        @initializers = parent ? parent.initializers.dup : []
      end

      def add(name, options = {}, &block)
        # If :before or :after is specified, set the index to the right spot
        if other = options[:before] || options[:after]
          raise Error, "The #{other.inspect} initializer does not exist" unless @names[other]
          index = @initializers.index(@names[other])
          index += 1 if options[:after]
        end

        @initializers.insert(index || -1, block)
        @names[name] = block
      end

      def delete(name)
        @names[name].tap do |initializer|
          @initializers.delete(initializer)
          @names.delete(name)
        end
      end

      def run_initializer(initializer)
        init_block = initializer.is_a?(Proc) ? initializer : @names[initializer]
        container = Class.new(Base, &init_block).new
        container.run if container.respond_to?(:run)
      end

      def run(initializer = nil)
        Base.config = @config

        if initializer
          run_initializer(initializer)
        else
          @initializers.each {|block| run_initializer(block) }
        end
      end
    end

    def self.default
      @default ||= Runner.new
    end

    def self.run(initializer = nil, config = nil)
      default.config = config if config
      default.run(initializer)
    end
  end

  # Check for valid Ruby version (1.8.2 or 1.8.4 or higher). This is done in an
  # external file, so we can use it from the `rails` program as well without duplication.
  Initializer.default.add :check_ruby_version do
    require 'ruby_version_check'
  end

  Initializer.default.add :set_root_path do
    raise 'RAILS_ROOT is not set' unless defined?(RAILS_ROOT)
    raise 'RAILS_ROOT is not a directory' unless File.directory?(RAILS_ROOT)

    configuration.root_path =
      # Pathname is incompatible with Windows, but Windows doesn't have
      # real symlinks so File.expand_path is safe.
      if RUBY_PLATFORM =~ /(:?mswin|mingw)/
        File.expand_path(RAILS_ROOT)

      # Otherwise use Pathname#realpath which respects symlinks.
      else
        Pathname.new(RAILS_ROOT).realpath.to_s
      end

    RAILS_ROOT.replace configuration.root_path
  end

  # If Rails is vendored and RubyGems is available, install stub GemSpecs
  # for Rails, Active Support, Active Record, Action Pack, Action Mailer, and
  # Active Resource. This allows Gem plugins to depend on Rails even when
  # the Gem version of Rails shouldn't be loaded.
  Initializer.default.add :install_gem_spec_stubs do
    unless Rails.respond_to?(:vendor_rails?)
      abort %{Your config/boot.rb is outdated: Run "rake rails:update".}
    end

    if Rails.vendor_rails?
      begin; require "rubygems"; rescue LoadError; return; end

      stubs = %w(rails activesupport activerecord actionpack actionmailer activeresource)
      stubs.reject! { |s| Gem.loaded_specs.key?(s) }

      stubs.each do |stub|
        Gem.loaded_specs[stub] = Gem::Specification.new do |s|
          s.name = stub
          s.version = Rails::VERSION::STRING
          s.loaded_from = ""
        end
      end
    end
  end

  # Set the <tt>$LOAD_PATH</tt> based on the value of
  # Configuration#load_paths. Duplicates are removed.
  Initializer.default.add :set_load_path do
    load_paths = configuration.load_paths + configuration.framework_paths
    load_paths.reverse_each { |dir| $LOAD_PATH.unshift(dir) if File.directory?(dir) }
    $LOAD_PATH.uniq!
  end

  Initializer.default.add :add_gem_load_paths do
    require 'rails/gem_dependency'
    Rails::GemDependency.add_frozen_gem_path
    unless @configuration.gems.empty?
      require "rubygems"
      @configuration.gems.each { |gem| gem.add_load_paths }
    end
  end

  # Requires all frameworks specified by the Configuration#frameworks
  # list. By default, all frameworks (Active Record, Active Support,
  # Action Pack, Action Mailer, and Active Resource) are loaded.
  Initializer.default.add :require_frameworks do
    begin
      require 'active_support/all'
      configuration.frameworks.each { |framework| require(framework.to_s) }
    rescue LoadError => e
      # Re-raise as RuntimeError because Mongrel would swallow LoadError.
      raise e.to_s
    end
  end

  # Set the paths from which Rails will automatically load source files, and
  # the load_once paths.
  Initializer.default.add :set_autoload_paths do
    require 'active_support/dependencies'
    ActiveSupport::Dependencies.load_paths = configuration.load_paths.uniq
    ActiveSupport::Dependencies.load_once_paths = configuration.load_once_paths.uniq

    extra = ActiveSupport::Dependencies.load_once_paths - ActiveSupport::Dependencies.load_paths
    unless extra.empty?
      abort <<-end_error
        load_once_paths must be a subset of the load_paths.
        Extra items in load_once_paths: #{extra * ','}
      end_error
    end

    # Freeze the arrays so future modifications will fail rather than do nothing mysteriously
    configuration.load_once_paths.freeze
  end

  # Adds all load paths from plugins to the global set of load paths, so that
  # code from plugins can be required (explicitly or automatically via ActiveSupport::Dependencies).
  Initializer.default.add :add_plugin_load_paths do
    require 'active_support/dependencies'
    plugin_loader.add_plugin_load_paths
  end

  # Loads the environment specified by Configuration#environment_path, which
  # is typically one of development, test, or production.
  Initializer.default.add :load_environment do
    silence_warnings do
      return if @environment_loaded
      @environment_loaded = true

      config = configuration
      constants = self.class.constants

      eval(IO.read(configuration.environment_path), binding, configuration.environment_path)

      (self.class.constants - constants).each do |const|
        Object.const_set(const, self.class.const_get(const))
      end
    end
  end

  # Preload all frameworks specified by the Configuration#frameworks.
  # Used by Passenger to ensure everything's loaded before forking and
  # to avoid autoload race conditions in JRuby.
  Initializer.default.add :preload_frameworks do
    if configuration.preload_frameworks
      configuration.frameworks.each do |framework|
        # String#classify and #constantize aren't available yet.
        toplevel = Object.const_get(framework.to_s.gsub(/(?:^|_)(.)/) { $1.upcase })
        toplevel.load_all! if toplevel.respond_to?(:load_all!)
      end
    end
  end

  # For Ruby 1.8, this initialization sets $KCODE to 'u' to enable the
  # multibyte safe operations. Plugin authors supporting other encodings
  # should override this behaviour and set the relevant +default_charset+
  # on ActionController::Base.
  #
  # For Ruby 1.9, UTF-8 is the default internal and external encoding.
  Initializer.default.add :initialize_encoding do
    if RUBY_VERSION < '1.9'
      $KCODE='u'
    else
      Encoding.default_internal = Encoding::UTF_8
      Encoding.default_external = Encoding::UTF_8
    end
  end

  # This initialization routine does nothing unless <tt>:active_record</tt>
  # is one of the frameworks to load (Configuration#frameworks). If it is,
  # this sets the database configuration from Configuration#database_configuration
  # and then establishes the connection.
  Initializer.default.add :initialize_database do
    if configuration.frameworks.include?(:active_record)
      ActiveRecord::Base.configurations = configuration.database_configuration
      ActiveRecord::Base.establish_connection
    end
  end

  Initializer.default.add :initialize_cache do
    unless defined?(RAILS_CACHE)
      silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(configuration.cache_store) }

      if RAILS_CACHE.respond_to?(:middleware)
        # Insert middleware to setup and teardown local cache for each request
        configuration.middleware.insert_after(:"Rack::Lock", RAILS_CACHE.middleware)
      end
    end
  end

  Initializer.default.add :initialize_framework_caches do
    if configuration.frameworks.include?(:action_controller)
      ActionController::Base.cache_store ||= RAILS_CACHE
    end
  end

  Initializer.default.add :initialize_logger do
    # if the environment has explicitly defined a logger, use it
    next if Rails.logger

    unless logger = configuration.logger
      begin
        logger = ActiveSupport::BufferedLogger.new(configuration.log_path)
        logger.level = ActiveSupport::BufferedLogger.const_get(configuration.log_level.to_s.upcase)
        if configuration.environment == "production"
          logger.auto_flushing = false
        end
      rescue StandardError => e
        logger = ActiveSupport::BufferedLogger.new(STDERR)
        logger.level = ActiveSupport::BufferedLogger::WARN
        logger.warn(
          "Rails Error: Unable to access log file. Please ensure that #{configuration.log_path} exists and is chmod 0666. " +
          "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
        )
      end
    end

    silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", logger }
  end

  # Sets the logger for Active Record, Action Controller, and Action Mailer
  # (but only for those frameworks that are to be loaded). If the framework's
  # logger is already set, it is not changed, otherwise it is set to use
  # RAILS_DEFAULT_LOGGER.
  Initializer.default.add :initialize_framework_logging do
    for framework in ([ :active_record, :action_controller, :action_mailer ] & configuration.frameworks)
      framework.to_s.camelize.constantize.const_get("Base").logger ||= Rails.logger
    end

    ActiveSupport::Dependencies.logger ||= Rails.logger
    Rails.cache.logger ||= Rails.logger
  end

  # Sets the dependency loading mechanism based on the value of
  # Configuration#cache_classes.
  Initializer.default.add :initialize_dependency_mechanism do
    ActiveSupport::Dependencies.mechanism = configuration.cache_classes ? :require : :load
  end

  # Loads support for "whiny nil" (noisy warnings when methods are invoked
  # on +nil+ values) if Configuration#whiny_nils is true.
  Initializer.default.add :initialize_whiny_nils do
    require('active_support/whiny_nil') if configuration.whiny_nils
  end


  # Sets the default value for Time.zone, and turns on ActiveRecord::Base#time_zone_aware_attributes.
  # If assigned value cannot be matched to a TimeZone, an exception will be raised.
  Initializer.default.add :initialize_time_zone do
    if configuration.time_zone
      zone_default = Time.__send__(:get_zone, configuration.time_zone)

      unless zone_default
        raise \
          'Value assigned to config.time_zone not recognized.' +
          'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
      end

      Time.zone_default = zone_default

      if configuration.frameworks.include?(:active_record)
        ActiveRecord::Base.time_zone_aware_attributes = true
        ActiveRecord::Base.default_timezone = :utc
      end
    end
  end

  # Set the i18n configuration from config.i18n but special-case for the load_path which should be
  # appended to what's already set instead of overwritten.
  Initializer.default.add :initialize_i18n do
    configuration.i18n.each do |setting, value|
      if setting == :load_path
        I18n.load_path += value
      else
        I18n.send("#{setting}=", value)
      end
    end
  end

  # Initializes framework-specific settings for each of the loaded frameworks
  # (Configuration#frameworks). The available settings map to the accessors
  # on each of the corresponding Base classes.
  Initializer.default.add :initialize_framework_settings do
    configuration.frameworks.each do |framework|
      base_class = framework.to_s.camelize.constantize.const_get("Base")

      configuration.send(framework).each do |setting, value|
        base_class.send("#{setting}=", value)
      end
    end
    configuration.active_support.each do |setting, value|
      ActiveSupport.send("#{setting}=", value)
    end
  end

  # Sets +ActionController::Base#view_paths+ and +ActionMailer::Base#template_root+
  # (but only for those frameworks that are to be loaded). If the framework's
  # paths have already been set, it is not changed, otherwise it is
  # set to use Configuration#view_path.
  Initializer.default.add :initialize_framework_views do
    if configuration.frameworks.include?(:action_view)
      view_path = ActionView::PathSet.type_cast(configuration.view_path)
      ActionMailer::Base.template_root  = view_path if configuration.frameworks.include?(:action_mailer) && ActionMailer::Base.view_paths.blank?
      ActionController::Base.view_paths = view_path if configuration.frameworks.include?(:action_controller) && ActionController::Base.view_paths.blank?
    end
  end

  Initializer.default.add :initialize_metal do
    Rails::Rack::Metal.requested_metals = configuration.metals
    Rails::Rack::Metal.metal_paths += plugin_loader.engine_metal_paths

    configuration.middleware.insert_before(
      :"ActionDispatch::ParamsParser",
      Rails::Rack::Metal, :if => Rails::Rack::Metal.metals.any?)
  end

  # Add the load paths used by support functions such as the info controller
  Initializer.default.add :add_support_load_paths do
  end

  Initializer.default.add :check_for_unbuilt_gems do
    unbuilt_gems = @configuration.gems.select {|gem| gem.frozen? && !gem.built? }
    if unbuilt_gems.size > 0
      # don't print if the gems:build rake tasks are being run
      unless $gems_build_rake_task
        abort <<-end_error
The following gems have native components that need to be built
#{unbuilt_gems.map { |gemm| "#{gemm.name}  #{gemm.requirement}" } * "\n  "}

You're running:
ruby #{Gem.ruby_version} at #{Gem.ruby}
rubygems #{Gem::RubyGemsVersion} at #{Gem.path * ', '}

Run `rake gems:build` to build the unbuilt gems.
        end_error
      end
    end
  end

  Initializer.default.add :load_gems do
    unless $gems_rake_task
      @configuration.gems.each { |gem| gem.load }
    end
  end

  # Loads all plugins in <tt>config.plugin_paths</tt>.  <tt>plugin_paths</tt>
  # defaults to <tt>vendor/plugins</tt> but may also be set to a list of
  # paths, such as
  #   config.plugin_paths = ["#{RAILS_ROOT}/lib/plugins", "#{RAILS_ROOT}/vendor/plugins"]
  #
  # In the default implementation, as each plugin discovered in <tt>plugin_paths</tt> is initialized:
  # * its +lib+ directory, if present, is added to the load path (immediately after the applications lib directory)
  # * <tt>init.rb</tt> is evaluated, if present
  #
  # After all plugins are loaded, duplicates are removed from the load path.
  # If an array of plugin names is specified in config.plugins, only those plugins will be loaded
  # and they plugins will be loaded in that order. Otherwise, plugins are loaded in alphabetical
  # order.
  #
  # if config.plugins ends contains :all then the named plugins will be loaded in the given order and all other
  # plugins will be loaded in alphabetical order
  Initializer.default.add :load_plugins do
    plugin_loader.load_plugins
  end

  #
  # # pick up any gems that plugins depend on
  Initializer.default.add :add_gem_load_paths do
    require 'rails/gem_dependency'
    Rails::GemDependency.add_frozen_gem_path
    unless @configuration.gems.empty?
      require "rubygems"
      @configuration.gems.each { |gem| gem.add_load_paths }
    end
  end

  # TODO: Figure out if this needs to run a second time
  # load_gems

  Initializer.default.add :check_gem_dependencies do
    unloaded_gems = @configuration.gems.reject { |g| g.loaded? }
    if unloaded_gems.size > 0
      configuration.gems_dependencies_loaded = false
      # don't print if the gems rake tasks are being run
      unless $gems_rake_task
        abort <<-end_error
Missing these required gems:
#{unloaded_gems.map { |gemm| "#{gemm.name}  #{gemm.requirement}" } * "\n  "}

You're running:
ruby #{Gem.ruby_version} at #{Gem.ruby}
rubygems #{Gem::RubyGemsVersion} at #{Gem.path * ', '}

Run `rake gems:install` to install the missing gems.
        end_error
      end
    else
      configuration.gems_dependencies_loaded = true
    end
  end

  # # bail out if gems are missing - note that check_gem_dependencies will have
  # # already called abort() unless $gems_rake_task is set
  # return unless gems_dependencies_loaded

  Initializer.default.add :load_application_initializers do
    if gems_dependencies_loaded
      Dir["#{configuration.root_path}/config/initializers/**/*.rb"].sort.each do |initializer|
        load(initializer)
      end
    end
  end

  # Fires the user-supplied after_initialize block (Configuration#after_initialize)
  Initializer.default.add :after_initialize do
    if gems_dependencies_loaded
      configuration.after_initialize_blocks.each do |block|
        block.call
      end
    end
  end

  # # Setup database middleware after initializers have run
  Initializer.default.add :initialize_database_middleware do
    if configuration.frameworks.include?(:active_record)
      if configuration.frameworks.include?(:action_controller) &&
          ActionController::Base.session_store.name == 'ActiveRecord::SessionStore'
        configuration.middleware.insert_before :"ActiveRecord::SessionStore", ActiveRecord::ConnectionAdapters::ConnectionManagement
        configuration.middleware.insert_before :"ActiveRecord::SessionStore", ActiveRecord::QueryCache
      else
        configuration.middleware.use ActiveRecord::ConnectionAdapters::ConnectionManagement
        configuration.middleware.use ActiveRecord::QueryCache
      end
    end
  end


  # # Prepare dispatcher callbacks and run 'prepare' callbacks
  Initializer.default.add :prepare_dispatcher do
    return unless configuration.frameworks.include?(:action_controller)
    require 'dispatcher' unless defined?(::Dispatcher)
    Dispatcher.define_dispatcher_callbacks(configuration.cache_classes)
  end

  # Routing must be initialized after plugins to allow the former to extend the routes
  # ---
  # If Action Controller is not one of the loaded frameworks (Configuration#frameworks)
  # this does nothing. Otherwise, it loads the routing definitions and sets up
  # loading module used to lazily load controllers (Configuration#controller_paths).
  Initializer.default.add :initialize_routing do
    return unless configuration.frameworks.include?(:action_controller)

    ActionController::Routing.controller_paths += configuration.controller_paths
    ActionController::Routing::Routes.add_configuration_file(configuration.routes_configuration_file)
    ActionController::Routing::Routes.reload!
  end
  #
  # # Observers are loaded after plugins in case Observers or observed models are modified by plugins.
  Initializer.default.add :load_observers do
    if gems_dependencies_loaded && configuration.frameworks.include?(:active_record)
      ActiveRecord::Base.instantiate_observers
    end
  end

  # # Load view path cache
  Initializer.default.add :load_view_paths do
    if configuration.frameworks.include?(:action_view)
      if configuration.cache_classes
        view_path = ActionView::FileSystemResolverWithFallback.new(configuration.view_path)
        ActionController::Base.view_paths = view_path if configuration.frameworks.include?(:action_controller)
        ActionMailer::Base.template_root = view_path if configuration.frameworks.include?(:action_mailer)
      end
    end
  end

  # Eager load application classes
  Initializer.default.add :load_application_classes do
    return if $rails_rake_task
    if configuration.cache_classes
      configuration.eager_load_paths.each do |load_path|
        matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
        Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
          require_dependency file.sub(matcher, '\1')
        end
      end
    end
  end

  # Disable dependency loading during request cycle
  Initializer.default.add :disable_dependency_loading do
    if configuration.cache_classes && !configuration.dependency_loading
      ActiveSupport::Dependencies.unhook!
    end
  end
end

# Needs to be duplicated from Active Support since its needed before Active
# Support is available. Here both Options and Hash are namespaced to prevent
# conflicts with other implementations AND with the classes residing in Active Support.
# ---
# TODO: w0t?
module Rails
  class << self
    # The Configuration instance used to configure the Rails environment
    def configuration
      @@configuration
    end

    def configuration=(configuration)
      @@configuration = configuration
    end

    def initialized?
      @initialized || false
    end

    def initialized=(initialized)
      @initialized ||= initialized
    end

    def logger
      if defined?(RAILS_DEFAULT_LOGGER)
        RAILS_DEFAULT_LOGGER
      else
        nil
      end
    end

    def backtrace_cleaner
      @@backtrace_cleaner ||= begin
        # Relies on ActiveSupport, so we have to lazy load to postpone definition until AS has been loaded
        require 'rails/backtrace_cleaner'
        Rails::BacktraceCleaner.new
      end
    end

    def root
      Pathname.new(RAILS_ROOT) if defined?(RAILS_ROOT)
    end

    def env
      @_env ||= ActiveSupport::StringInquirer.new(RAILS_ENV)
    end

    def cache
      RAILS_CACHE
    end

    def version
      VERSION::STRING
    end

    def public_path
      @@public_path ||= self.root ? File.join(self.root, "public") : "public"
    end

    def public_path=(path)
      @@public_path = path
    end
  end
  class OrderedOptions < Array #:nodoc:
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
end