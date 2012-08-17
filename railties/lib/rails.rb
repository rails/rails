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
  autoload :InfoController, 'rails/info_controller'
  autoload :Queueing, 'rails/queueing'

  class << self
    def application
      @application ||= nil
    end

    def application=(application)
      @application = application
    end

    # The Configuration instance used to configure the Rails environment
    def configuration
      application.config
    end

    # Rails.queue is the application's queue. You can push a job onto
    # the queue by:
    #
    #   Rails.queue.push job
    #
    # A job is an object that responds to +run+. Queue consumers will
    # pop jobs off of the queue and invoke the queue's +run+ method.
    #
    # Note that depending on your queue implementation, jobs may not
    # be executed in the same process as they were created in, and
    # are never executed in the same thread as they were created in.
    #
    # If necessary, a queue implementation may need to serialize your
    # job for distribution to another process. The documentation of
    # your queue will specify the requirements for that serialization.
    def queue
      application.queue
    end

    def initialize!
      application.initialize!
    end

    def initialized?
      application.initialized?
    end

    # Rails.logger provides access to the logger. You can use this to log
    # information beyond what Rails logs by default:
    #
    #   Rails.logger.info "I crave spaghetti" #=> true
    #   Rails.logger.fatal "Out of disk space" #=> true
    #
    # When using the default ActiveSupport::TaggedLogging configuration,
    # the above examples will be written into log/development.log during
    # development.
    def logger
      @logger ||= nil
    end

    def logger=(logger)
      @logger = logger
    end

    def backtrace_cleaner
      @backtrace_cleaner ||= begin
        # Relies on Active Support, so we have to lazy load to postpone definition until AS has been loaded
        require 'rails/backtrace_cleaner'
        Rails::BacktraceCleaner.new
      end
    end

    # Rails.root returns a Pathname instance pointing to the application root, like a
    # smarter RAILS_ROOT.
    #
    #   Rails.root #=> #<Pathname:/User/you/rails-app>
    #   Rails.root.to_s #=> "/User/you/rails-app"
    #
    # Since this is a Pathname, you can operate with it:
    #
    #   (Rails.root + 'tmp').children #=> [#<Pathname:/User/you/rails-app/tmp/emergency_smile.txt>]
    #   (Rails.root + 'tmp' + 'emergency_smile.txt').read #=> ":)"
    #
    # Pathname has been part of the Ruby standard library since 1.8.0.
    def root
      application && application.config.root
    end

    # Rails.env returns the current environment the application is running in,
    # such as "development" or "test".
    #
    # You can query this directly instead of checking for string equality.
    # For example, while you're running tests:
    #
    #   Rails.env #=> "test"
    #   Rails.env.development? #=> false
    #   Rails.env.test? #=> true
    #   Rails.env.environment_i_just_made_up? #=> false
    #
    # This functionality is provided by ActiveSupport::StringInquirer
    def env
      @_env ||= ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development")
    end

    def env=(environment)
      @_env = ActiveSupport::StringInquirer.new(environment)
    end

    def cache
      @cache ||= nil
    end

    def cache=(cache)
      @cache = cache
    end

    # Returns all rails groups for loading based on:
    #
    # * The Rails environment;
    # * The environment variable RAILS_GROUPS;
    # * The optional envs given as argument and the hash with group dependencies;
    #
    #   groups :assets => [:development, :test]
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

    # Returns a String of the path to the public directory that static files are
    # served from.
    #
    #   Rails.public_path #=> "/User/you/rails-app/public"
    def public_path
      application && application.paths["public"].first
    end
  end
end
