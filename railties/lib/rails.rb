require 'rails/ruby_version_check'

require 'pathname'

require 'active_support'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/array/extract_options'

require 'rails/application'
require 'rails/version'
require 'rails/deprecation'

require 'active_support/railtie'
require 'action_dispatch/railtie'

# For Ruby 1.9, UTF-8 is the default internal and external encoding.
silence_warnings do
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

module Rails
  autoload :Info, 'rails/info'
  autoload :InfoController,    'rails/info_controller'
  autoload :WelcomeController, 'rails/welcome_controller'

  class << self
    attr_accessor :application, :cache, :logger

    # These methods access and write to the global configuration of the
    # Rails application, denoted by +Rails.config+. Although multiple rails
    # applications are allowed, only a single Rails.config is allowed. 
    #
    # The +Rails.config+ is set to the configuration of the first application
    # that is initialized. For example,
    #
    #   class MyNewApp < Rails::Application
    #   end
    #
    #   MyNewApp.new do
    #     config.some_configuration = "some configuration"
    #   end
    #
    # If the above is the first application that is initialized, then
    # +Rails.config+ will be set to the config of the above application.
    def config
      @config ||= Application::Configuration.new(Rails::Engine.find_root_with_flag("config.ru", Dir.pwd)))
    end

    # The @config variable is set on the first instantiation of a
    # Rails::Application object. This configuration then becomes the global
    # configuration to be used for all applications.
    def config=(configuration)
      @config = configuration
    end

    alias :configuration :config

    def initialize!
      application.initialize!
    end

    def initialized?
      application.initialized?
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= begin
        # Relies on Active Support, so we have to lazy load to postpone definition until AS has been loaded
        require 'rails/backtrace_cleaner'
        Rails::BacktraceCleaner.new
      end
    end

    # This method stores the rake tasks for the main Rails application.
    # Whenever a new application is configured, the new rake tasks are
    # sent to this method.
    #
    # The +@rake_tasks+ variable serves as a global store of all the rake
    # tasks available to any application that has been configured.
    def rake_tasks(&blk)
      @rake_tasks ||= []
      @rake_tasks << blk if blk
      @rake_tasks
    end

    def root
      application && application.config.root
    end

    def env
      @_env ||= ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development")
    end

    def env=(environment)
      @_env = ActiveSupport::StringInquirer.new(environment)
    end

    # Returns all rails groups for loading based on:
    #
    # * The Rails environment;
    # * The environment variable RAILS_GROUPS;
    # * The optional envs given as argument and the hash with group dependencies;
    #
    #   groups assets: [:development, :test]
    #
    #   # Returns
    #   # => [:default, :development, :assets] for Rails.env == "development"
    #   # => [:default, :production]           for Rails.env == "production"
    def groups(*groups)
      hash = groups.extract_options!
      env = Rails.env
      groups.unshift(:default, env)
      groups.concat ENV["RAILS_GROUPS"].to_s.split(",")
      groups.concat hash.map { |k,v| k if v.map(&:to_s).include?(env) }
      groups.compact!
      groups.uniq!
      groups
    end

    def version
      VERSION::STRING
    end

    def public_path
      application && Pathname.new(application.paths["public"].first)
    end
  end
end
