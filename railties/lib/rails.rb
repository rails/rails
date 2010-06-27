require 'rails/ruby_version_check'

require 'pathname'

require 'active_support'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/logger'

require 'rails/application'
require 'rails/version'
require 'rails/deprecation'

require 'active_support/railtie'
require 'action_dispatch/railtie'

# For Ruby 1.8, this initialization sets $KCODE to 'u' to enable the
# multibyte safe operations. Plugin authors supporting other encodings
# should override this behaviour and set the relevant +default_charset+
# on ActionController::Base.
#
# For Ruby 1.9, UTF-8 is the default internal and external encoding.
if RUBY_VERSION < '1.9'
  $KCODE='u'
else
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

module Rails
  autoload :Info, 'rails/info'
  autoload :InfoController, 'rails/info_controller'

  class << self
    def application
      @@application ||= nil
    end

    def application=(application)
      @@application = application
    end

    # The Configuration instance used to configure the Rails environment
    def configuration
      application.config
    end

    def initialize!
      application.initialize!
    end

    def initialized?
      @@initialized || false
    end

    def initialized=(initialized)
      @@initialized ||= initialized
    end

    def logger
      @@logger ||= nil
    end

    def logger=(logger)
      @@logger = logger
    end

    def backtrace_cleaner
      @@backtrace_cleaner ||= begin
        # Relies on Active Support, so we have to lazy load to postpone definition until AS has been loaded
        require 'rails/backtrace_cleaner'
        Rails::BacktraceCleaner.new
      end
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

    def cache
      RAILS_CACHE
    end

    def version
      VERSION::STRING
    end

    def public_path
      application && application.paths.public.to_a.first
    end

    def public_path=(path)
      ActiveSupport::Deprecation.warn "Setting Rails.public_path= is deprecated. " <<
        "Please set paths.public = in config/application.rb instead.", caller
    end
  end
end
