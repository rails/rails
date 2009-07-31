require "pathname"

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'railties_path'
require 'rails/version'
require 'rails/gem_dependency'
require 'rails/rack'
require 'rails/paths'
require 'rails/core'
require 'rails/configuration'

RAILS_ENV = (ENV['RAILS_ENV'] || 'development').dup unless defined?(RAILS_ENV)

module Rails
  # Sanity check to make sure this file is only loaded once
  # TODO: Get to the point where this can be removed.
  raise "It looks like initializer.rb was required twice" if defined?(Initializer)

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
        Rails.configuration = Base.config = @config

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
      default.config ||= Configuration.new
      yield default.config if block_given?
      default.run(initializer)
    end
  end

  # Check for valid Ruby version (1.8.2 or 1.8.4 or higher). This is done in an
  # external file, so we can use it from the `rails` program as well without duplication.
  Initializer.default.add :check_ruby_version do
    require 'ruby_version_check'
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

      %w(rails activesupport activerecord actionpack actionmailer activeresource).each do |stub|
        Gem.loaded_specs[stub] ||= Gem::Specification.new do |s|
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
    # TODO: Think about unifying this with the general Rails paths
    configuration.framework_paths.reverse_each { |dir| $LOAD_PATH.unshift(dir) if File.directory?(dir) }
    configuration.paths.add_to_load_path
    $LOAD_PATH.uniq!
  end

  Initializer.default.add :add_gem_load_paths do
    require 'rails/gem_dependency'
    Rails::GemDependency.add_frozen_gem_path
    unless config.gems.empty?
      require "rubygems"
      config.gems.each { |gem| gem.add_load_paths }
    end
  end

  # Requires all frameworks specified by the Configuration#frameworks
  # list. By default, all frameworks (Active Record, Active Support,
  # Action Pack, Action Mailer, and Active Resource) are loaded.
  Initializer.default.add :require_frameworks do
    begin
      require 'active_support'
      require 'active_support/core_ext/kernel/reporting'
      require 'active_support/core_ext/logger'

      # TODO: This is here to make Sam Ruby's tests pass. Needs discussion.
      require 'active_support/core_ext/numeric/bytes'
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
      next if @environment_loaded
      next unless File.file?(configuration.environment_path)

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
        if RAILS_ENV == "production"
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

    # TODO: Why are we silencing warning here?
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
    # TODO: Remove files from the $" and always use require
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
    # TODO: Make Rails and metal work without ActionController
    if defined?(ActionController)
      Rails::Rack::Metal.requested_metals = configuration.metals
      Rails::Rack::Metal.metal_paths += plugin_loader.engine_metal_paths

      configuration.middleware.insert_before(
        :"ActionDispatch::ParamsParser",
        Rails::Rack::Metal, :if => Rails::Rack::Metal.metals.any?)
    end
  end

  Initializer.default.add :check_for_unbuilt_gems do
    unbuilt_gems = config.gems.select {|gem| gem.frozen? && !gem.built? }
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
      config.gems.each { |gem| gem.load }
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
    # TODO: This seems extraneous
    Rails::GemDependency.add_frozen_gem_path
    unless config.gems.empty?
      require "rubygems"
      config.gems.each { |gem| gem.add_load_paths }
    end
  end

  # TODO: Figure out if this needs to run a second time
  # load_gems

  Initializer.default.add :check_gem_dependencies do
    unloaded_gems = config.gems.reject { |g| g.loaded? }
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

  # TODO: Make a DSL way to limit an initializer to a particular framework

  # # Prepare dispatcher callbacks and run 'prepare' callbacks
  Initializer.default.add :prepare_dispatcher do
    next unless configuration.frameworks.include?(:action_controller)
    require 'dispatcher' unless defined?(::Dispatcher)
    Dispatcher.define_dispatcher_callbacks(configuration.cache_classes)
  end

  # Routing must be initialized after plugins to allow the former to extend the routes
  # ---
  # If Action Controller is not one of the loaded frameworks (Configuration#frameworks)
  # this does nothing. Otherwise, it loads the routing definitions and sets up
  # loading module used to lazily load controllers (Configuration#controller_paths).
  Initializer.default.add :initialize_routing do
    next unless configuration.frameworks.include?(:action_controller)

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

  # Eager load application classes
  Initializer.default.add :load_application_classes do
    next if $rails_rake_task

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

  # Configure generators if they were already loaded
  Initializer.default.add :initialize_generators do
    if defined?(Rails::Generators)
      Rails::Generators.no_color! unless config.generators.colorize_logging
      Rails::Generators.aliases.deep_merge! config.generators.aliases
      Rails::Generators.options.deep_merge! config.generators.options
    end
  end
end
