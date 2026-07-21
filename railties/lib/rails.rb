# frozen_string_literal: true

require "pathname"

require "active_support"
require "active_support/rails"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/array/extract_options"

require "rails/version"
require "rails/deprecator"
require "rails/application"
require "rails/backtrace_cleaner"

require "active_support/railtie"
require "action_dispatch/railtie"

# UTF-8 is the default internal and external encoding.
silence_warnings do
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

# :include: ../README.rdoc
module Rails
  extend ActiveSupport::Autoload
  extend ActiveSupport::Benchmarkable

  autoload :Info
  autoload :InfoController
  autoload :MailersController
  autoload :WelcomeController
  autoload :DevtoolsController

  eager_autoload do
    autoload :HealthController
    autoload :PwaController
  end

  class << self
    attr_writer :application
    attr_accessor :app_class, :cache, :logger
    def application
      @application ||= (app_class.instance if app_class)
    end

    alias :app :application
    delegate :initialize!, :initialized?, to: :application

    # The Configuration instance used to configure the \Rails environment
    def configuration
      application.config
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= Rails::BacktraceCleaner.new
    end

    # Returns a Pathname object of the current \Rails project,
    # otherwise it returns +nil+ if there is no project:
    #
    #   Rails.root
    #     # => #<Pathname:/Users/someuser/some/path/project>
    def root
      application && application.config.root
    end

    # Returns the current \Rails environment.
    #
    #   Rails.env # => "development"
    #   Rails.env.development? # => true
    #   Rails.env.production? # => false
    #   Rails.env.local? # => true              true for "development" and "test", false for anything else
    def env
      @_env ||= ActiveSupport::EnvironmentInquirer.new(ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development")
    end

    # Sets the \Rails environment.
    #
    #   Rails.env = "staging" # => "staging"
    def env=(environment)
      @_env = ActiveSupport::EnvironmentInquirer.new(environment)
    end

    # Returns the ActiveSupport::ErrorReporter instance used for reporting
    # errors.
    #
    #   Rails.error.handle(IOError) do
    #     # ...
    #   end
    #   Rails.error.report(error)
    def error
      ActiveSupport.error_reporter
    end

    # Returns the ActiveSupport::EventReporter instance used for broadcasting
    # structured events.
    #
    #   Rails.event.notify("my_event", { message: "Hello, world!" })
    def event
      ActiveSupport.event_reporter
    end

    # Returns all \Rails groups for loading based on:
    #
    # * The \Rails environment;
    # * The environment variable RAILS_GROUPS;
    # * The optional envs given as argument and the hash with group dependencies;
    #
    #  Rails.groups assets: [:development, :test]
    #  # => [:default, "development", :assets] for Rails.env == "development"
    #  # => [:default, "production"]           for Rails.env == "production"
    def groups(*groups)
      hash = groups.extract_options!
      env = Rails.env
      groups.unshift(:default, env)
      groups.concat ENV["RAILS_GROUPS"].to_s.split(",")
      groups.concat hash.map { |k, v| k if v.map(&:to_s).include?(env) }
      groups.compact!
      groups.uniq!
      groups
    end

    # Returns a Pathname object of the public folder of the current
    # \Rails project, otherwise it returns +nil+ if there is no project:
    #
    #   Rails.public_path
    #     # => #<Pathname:/Users/someuser/some/path/project/public>
    def public_path
      application && Pathname.new(application.paths["public"].first)
    end

    # Provides access to the application autoloaders.
    #
    # The autoloader that manages `autoload_paths` is reachable as
    #
    #   Rails.autoloaders.main
    #
    # This autoloader manages the constants that are reloaded when reloading is
    # enabled.
    #
    # The autoloader that manages `autoload_once_paths` is reachable as
    #
    #   Rails.autoloaders.once
    #
    # This autoloader manages constants that are autoloaded, but not reloaded.
    #
    # You can use these objects to customize their behavior, defining custom
    # root namespaces, collapsing directories, configuring callbacks, etc.
    #
    #   # config/environments/development.rb
    #   Rails.autoloaders.main.on_load("MyGateway") do
    #     MyGateway.endpoint = "https://my-gateway.localhost"
    #   end
    #
    #   # config/environments/production.rb
    #   Rails.autoloaders.main.on_load("MyGateway") do
    #     MyGateway.endpoint = "https://my-gateway.example.com"
    #   end
    #
    # The +each+ iterator allows you to iterate over both loaders:
    #
    #   Rails.autoloaders.each do |loader|
    #     loader.log!
    #   end
    #
    # which may be handy if you want to run the same code for both of them.
    #
    # Indeed, there is a shortcut for that common use case:
    #
    #   Rails.autoloaders.log!
    #
    # which is handy to watch the activity of the autoloaders.
    #
    # Finally, +zeitwerk_enabled?+ allows you to check if autoloading is powered
    # by Zeitwerk. This predicate returns a hard-coded true since Rails 7, but
    # it is still in place for engines that support Rails 6.
    #
    # The autoloaders are available really early, you can access them in the
    # application class body, environment configuration, initializers, etc.
    #
    # Please check the {Autoloading and Reloading
    # Constants}[https://guides.rubyonrails.org/autoloading_and_reloading_constants.html]
    # guide and the documentation of {Zeitwerk}[https://github.com/fxn/zeitwerk]
    # itself for more details and usage patterns.
    def autoloaders
      application.autoloaders
    end
  end
end
