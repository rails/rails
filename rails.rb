# frozen_string_literal: true

require "rails/ruby_version_check"

require "pathname"

require "active_support"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/object/blank"

require "rails/application"
require "rails/version"

require "active_support/railtie"
require "action_dispatch/railtie"

# UTF-8 is the default internal and external encoding.
silence_warnings do
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

module Rails
  extend ActiveSupport::Autoload
  extend ActiveSupport::Benchmarkable

  autoload :Info
  autoload :InfoController
  autoload :MailersController
  autoload :WelcomeController

  class << self
    @application = @app_class = nil

    attr_writer :application
    attr_accessor :app_class, :cache, :logger
    def application
      @application ||= (app_class.instance if app_class)
    end

    delegate :initialize!, :initialized?, to: :application

    # The Configuration instance used to configure the Rails environment
    def configuration
      application.config
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= begin
        # Relies on Active Support, so we have to lazy load to postpone definition until Active Support has been loaded
        require "rails/backtrace_cleaner"
        Rails::BacktraceCleaner.new
      end
    end

    # Returns a Pathname object of the current Rails project,
    # otherwise it returns +nil+ if there is no project:
    #
    #   Rails.root
    #     # => #<Pathname:/Users/someuser/some/path/project>
    def root
      application && application.config.root
    end

    # Returns the current Rails environment.
    #
    #   Rails.env # => "development"
    #   Rails.env.development? # => true
    #   Rails.env.production? # => false
    def env
      @_env ||= ActiveSupport::EnvironmentInquirer.new(ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development")
    end

    # Sets the Rails environment.
    #
    #   Rails.env = "staging" # => "staging"
    def env=(environment)
      @_env = ActiveSupport::EnvironmentInquirer.new(environment)
    end

    # Returns the ActiveSupport::ErrorReporter of the current Rails project,
    # otherwise it returns +nil+ if there is no project.
    #
    #   Rails.error.handle(IOError) do
    #     # ...
    #   end
    #   Rails.error.report(error)
    def error
      application && application.executor.error_reporter
    end

    # Returns all Rails groups for loading based on:
    #
    # * The Rails environment;
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
    # Rails project, otherwise it returns +nil+ if there is no project:
    #
    #   Rails.public_path
    #     # => #<Pathname:/Users/someuser/some/path/project/public>
    def public_path
      application && Pathname.new(application.paths["public"].first)
    end

    def autoloaders
      application.autoloaders
    end
  end
end
