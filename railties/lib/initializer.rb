require 'logger'

RAILS_ENV = (ENV['RAILS_ENV'] || 'development').dup unless defined?(RAILS_ENV)

module Rails
  # The Initializer is responsible for processing the Rails configuration, such as setting the $LOAD_PATH, requiring the
  # right frameworks, initializing logging, and more. It can be run either as a single command that'll just use the 
  # default configuration, like this:
  #
  #   Rails::Initializer.run
  #
  # But normally it's more interesting to pass in a custom configuration through the block running:
  #
  #   Rails::Initializer.run do |config|
  #     config.frameworks -= [ :action_web_service ]
  #   end
  #
  # This will use the default configuration options from Rails::Configuration, but allow for overwriting on select areas.
  class Initializer
    attr_reader :configuration
    
    def self.run(command = :process, configuration = Configuration.new)
      yield configuration if block_given?
      new(configuration).send(command)
    end
    
    def initialize(configuration)
      @configuration = configuration
    end
    
    def process
      set_load_path
      set_connection_adapters

      require_frameworks
      load_environment

      initialize_database
      initialize_fixture_settings if configuration.environment == 'test'
      initialize_logger
      initialize_framework_logging
      initialize_framework_views
      initialize_routing
      initialize_dependency_mechanism
      initialize_breakpoints
      initialize_whiny_nils
      
      intitialize_framework_settings
      
      # Support for legacy configuration style where the environment
      # could overwrite anything set from the defaults/global through
      # the individual base class configurations.
      load_environment

      load_plugins
    end
    
    def set_load_path
      configuration.load_paths.reverse.each { |dir| $LOAD_PATH.unshift(dir) if File.directory?(dir) }
      $LOAD_PATH.uniq!
    end
    
    def set_connection_adapters
      Object.const_set("RAILS_CONNECTION_ADAPTERS", configuration.connection_adapters) if configuration.connection_adapters
    end
    
    def require_frameworks
      configuration.frameworks.each { |framework| require(framework.to_s) }
    end
    
    def load_plugins
      config = configuration

      Dir.glob("#{configuration.plugins_path}/*") do |directory|
        next if File.basename(directory)[0] == ?. || !File.directory?(directory)

        if File.directory?("#{directory}/lib")
          $LOAD_PATH.unshift "#{directory}/lib"
        end

        if File.exist?("#{directory}/init.rb")
          silence_warnings do
            eval(IO.read("#{directory}/init.rb"), binding)
          end
        end
      end

      $LOAD_PATH.uniq!
    end

    def load_environment
      silence_warnings do
        config = configuration
        eval(IO.read(configuration.environment_path), binding)
      end
    end
    
    def initialize_database
      return unless configuration.frameworks.include?(:active_record)
      ActiveRecord::Base.configurations = configuration.database_configuration
      ActiveRecord::Base.establish_connection
    end
    
    def initialize_fixture_settings
      return unless configuration.frameworks.include?(:active_record)
      require 'test/unit'
      require 'active_record/fixtures'
      Test::Unit::TestCase.use_transactional_fixtures = configuration.transactional_fixtures
      Test::Unit::TestCase.use_instantiated_fixtures = configuration.instantiated_fixtures
      Test::Unit::TestCase.pre_loaded_fixtures = configuration.pre_loaded_fixtures
    end
    
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
    
    def initialize_framework_logging
      for framework in ([ :active_record, :action_controller, :action_mailer ] & configuration.frameworks)
        framework.to_s.camelize.constantize.const_get("Base").logger ||= RAILS_DEFAULT_LOGGER
      end
    end
    
    def initialize_framework_views
      for framework in ([ :action_controller, :action_mailer ] & configuration.frameworks)
        framework.to_s.camelize.constantize.const_get("Base").template_root ||= configuration.view_path
      end
    end

    def initialize_routing
      return unless configuration.frameworks.include?(:action_controller)
      ActionController::Routing::Routes.reload
      Object.const_set "Controllers", Dependencies::LoadingModule.root(*configuration.controller_paths)
    end
    
    def initialize_dependency_mechanism
      Dependencies.mechanism = configuration.cache_classes ? :require : :load
    end
    
    def initialize_breakpoints
      silence_warnings { Object.const_set("BREAKPOINT_SERVER_PORT", 42531) if configuration.breakpoint_server }
    end
    
    def initialize_whiny_nils
      require('active_support/whiny_nil') if configuration.whiny_nils
    end

    def intitialize_framework_settings
      configuration.frameworks.each do |framework|
        base_class = framework.to_s.camelize.constantize.const_get("Base")

        configuration.send(framework).each do |setting, value|
          base_class.send("#{setting}=", value)
        end
      end
    end
  end
  
  # The Configuration class holds all the parameters for the Initializer and ships with defaults that suites most
  # Rails applications. But it's possible to overwrite everything. Usually, you'll create an Configuration file implicitly
  # through the block running on the Initializer, but it's also possible to create the Configuration instance in advance and
  # pass it in like this:
  #
  #   config = Rails::Configuration.new
  #   Rails::Initializer.run(:process, config)
  class Configuration
    attr_accessor :frameworks, :load_paths, :logger, :log_level, :log_path, :database_configuration_file, :view_path, :controller_paths
    attr_accessor :cache_classes, :breakpoint_server, :whiny_nils
    attr_accessor :transactional_fixtures, :instantiated_fixtures, :pre_loaded_fixtures
    attr_accessor :connection_adapters
    attr_accessor :active_record, :action_controller, :action_view, :action_mailer, :action_web_service
    
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
      self.database_configuration_file  = default_database_configuration_file
      self.transactional_fixtures       = default_transactional_fixtures
      self.instantiated_fixtures        = default_use_instantiated_fixtures
      self.pre_loaded_fixtures          = default_pre_loaded_fixtures
      
      for framework in default_frameworks
        self.send("#{framework}=", OrderedOptions.new)
      end
    end
    
    def database_configuration
      YAML::load(ERB.new(IO.read(database_configuration_file)).result)
    end
    
    def environment_path
      "#{RAILS_ROOT}/config/environments/#{environment}.rb"
    end

    def plugins_path
      "#{RAILS_ROOT}/vendor/plugins"
    end
    
    def environment
      ::RAILS_ENV
    end

    private
      def default_frameworks
        [ :active_record, :action_controller, :action_view, :action_mailer, :action_web_service ]
      end
    
      def default_load_paths
        paths = ["#{RAILS_ROOT}/test/mocks/#{environment}"]

        # Then model subdirectories.
        # TODO: Don't include .rb models as load paths
        paths.concat(Dir["#{RAILS_ROOT}/app/models/[_a-z]*"])
        paths.concat(Dir["#{RAILS_ROOT}/components/[_a-z]*"])

        # Followed by the standard includes.
        # TODO: Don't include dirs for frameworks that are not used
        paths.concat %w(
          app 
          app/models 
          app/controllers 
          app/helpers 
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
        ).map { |dir| "#{RAILS_ROOT}/#{dir}" }.select { |dir| File.directory?(dir) }
      end

      def default_log_path
        File.join(RAILS_ROOT, 'log', "#{environment}.log")
      end
      
      def default_log_level
        environment == 'production' ? :info : :debug
      end
      
      def default_database_configuration_file
        File.join(RAILS_ROOT, 'config', 'database.yml')
      end
      
      def default_view_path
        File.join(RAILS_ROOT, 'app', 'views')
      end
      
      def default_controller_paths
        [ File.join(RAILS_ROOT, 'app', 'controllers'), File.join(RAILS_ROOT, 'components') ]
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
           
      def default_transactional_fixtures
        true
      end
      
      def default_use_instantiated_fixtures
        false
      end
      
      def default_pre_loaded_fixtures
        false
      end
  end
end

# Needs to be duplicated from Active Support since its needed before Active Support is available
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
